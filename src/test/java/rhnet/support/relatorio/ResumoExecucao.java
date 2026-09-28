package rhnet.support.relatorio;

import io.karatelabs.core.FeatureResult;
import io.karatelabs.core.ScenarioResult;
import io.karatelabs.core.SuiteResult;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Gera, ao final da execução:
 *   target/resumo-execucao.md    tabela de resultados em português, exibida no GitHub Actions
 *   target/resumo-execucao.json  números da execução, usados na página inicial publicada
 *   target/resumo-console.txt    resumo curto exibido no terminal (resultado e falhas)
 * Falhas na geração nunca alteram o resultado dos testes.
 *
 * Para manter o resumo curto, ele traz apenas a primeira linha de cada falha:
 * o detalhe completo fica nos relatórios Allure e Karate.
 */
public final class ResumoExecucao {

    private static final DateTimeFormatter DATA_HORA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final ZoneId FUSO = ZoneId.of("America/Sao_Paulo");

    private ResumoExecucao() {
    }

    public static void gerar(SuiteResult resultado, String ambiente) {
        String momento = ZonedDateTime.now(FUSO).format(DATA_HORA);
        try {
            Files.createDirectories(Path.of("target"));
            Files.writeString(Path.of("target", "resumo-execucao.md"),
                    montar(resultado, ambiente, momento), StandardCharsets.UTF_8);
            Files.writeString(Path.of("target", "resumo-execucao.json"),
                    json(resultado, ambiente, momento), StandardCharsets.UTF_8);
            Files.writeString(Path.of("target", "resumo-console.txt"),
                    console(resultado, ambiente), StandardCharsets.UTF_8);
        } catch (Exception e) {
            System.err.println("Não foi possível gerar o resumo da execução: " + e.getMessage());
        }
    }

    /**
     * Resumo curto para o terminal: o resultado geral e as falhas agrupadas por causa.
     * Cenários que falharam pelo mesmo motivo aparecem em uma única entrada.
     */
    public static String console(SuiteResult resultado, String ambiente) {
        int total = resultado.getScenarioCount();
        int falhas = resultado.getScenarioFailedCount();
        StringBuilder sb = new StringBuilder();
        sb.append("Resultado em ").append(ambiente.toUpperCase(Locale.ROOT)).append(": ")
          .append(resultado.getScenarioPassedCount()).append(" de ").append(total).append(" cenários passaram")
          .append(falhas > 0 ? " | " + falhas + " falharam" : "")
          .append(" | ").append(duracao(resultado.getDurationMillis())).append("\n");
        if (falhas == 0) {
            return sb.toString();
        }

        // Agrupa os cenários com falha pela causa
        Map<List<String>, List<String>> porCausa = new LinkedHashMap<>();
        for (FeatureResult fr : resultado.getFeatureResults()) {
            for (ScenarioResult r : fr.getScenarioResults()) {
                if (r.isFailed()) {
                    porCausa.computeIfAbsent(causaEOnde(r.getFailureMessage()), k -> new ArrayList<>())
                            .add(r.getScenario().getFeature().getName() + ": " + r.getScenario().getName());
                }
            }
        }

        sb.append("\nFalhas (").append(porCausa.size()).append(porCausa.size() == 1 ? " causa" : " causas").append("):\n");
        if (porCausa.size() == 1 && falhas == total && total > 1) {
            sb.append("  Todos os cenários falharam pelo mesmo motivo: indica problema de configuração\n")
              .append("  ou de ambiente, não da API. Veja a causa abaixo.\n");
        }
        int exibidas = 0;
        for (Map.Entry<List<String>, List<String>> causa : porCausa.entrySet()) {
            if (exibidas++ == 15) {
                sb.append("\n  ... e mais ").append(porCausa.size() - 15).append(" causa(s) (veja o relatório)\n");
                break;
            }
            String motivo = causa.getKey().get(0);
            String onde = causa.getKey().get(1);
            List<String> cenarios = causa.getValue();
            sb.append("\n");
            if (cenarios.size() == 1) {
                sb.append("  - ").append(cenarios.get(0)).append("\n")
                  .append("      ").append(motivo).append("\n");
                if (!onde.isEmpty()) {
                    sb.append("      Onde: ").append(onde).append("\n");
                }
            } else {
                sb.append("  - ").append(motivo).append("\n");
                if (!onde.isEmpty()) {
                    sb.append("      Onde: ").append(onde).append("\n");
                }
                sb.append("      ").append(cenarios.size()).append(" cenários, entre eles:\n");
                for (int i = 0; i < Math.min(3, cenarios.size()); i++) {
                    sb.append("        ").append(cenarios.get(i)).append("\n");
                }
            }
        }
        return sb.toString();
    }

    /**
     * Causa de uma falha em uma linha, e onde ela ocorreu (quando informado).
     * - Erros de JavaScript do Karate ("js failed:"): usa as linhas "Error:" e "Code:".
     * - Falhas de status: remove o tempo de resposta e a URL, que já estão no relatório.
     * - Falhas de match: acrescenta a linha que descreve a divergência.
     */
    static List<String> causaEOnde(String mensagem) {
        if (mensagem == null || mensagem.isBlank()) {
            return List.of("Falha sem mensagem (veja o relatório)", "");
        }
        String[] linhas = mensagem.split("\\R");

        // Erro de JavaScript do Karate: "Code:" e "Error:" (o erro pode ocupar várias linhas,
        // até a linha "==========" que fecha o bloco)
        String codigo = "";
        StringBuilder erro = null;
        for (int i = 0; i < linhas.length; i++) {
            String l = linhas[i].trim();
            if (l.startsWith("Code:") && codigo.isEmpty()) {
                codigo = limitar(l.substring(5).trim(), 100);
            } else if (l.startsWith("Error:") && erro == null) {
                erro = new StringBuilder(l.substring(6).trim());
                for (int j = i + 1; j < linhas.length && !linhas[j].trim().equals("=========="); j++) {
                    erro.append('\n').append(linhas[j]);
                }
            }
        }
        if (erro != null) {
            String texto = erro.toString().trim();
            // Falhas geradas pelo próprio projeto (karate.fail) já explicam a causa: o código não ajuda
            String onde = codigo.contains("karate.fail(") ? "" : codigo;
            String contrato = resumoContrato(texto);
            if (contrato != null) {
                return List.of(contrato, "");
            }
            return List.of(limitar(primeiraLinha(texto), 220), onde);
        }

        String primeira = primeiraLinha(mensagem);
        int corte = primeira.indexOf(", response time");
        if (corte > 0) {
            primeira = primeira.substring(0, corte);
        }
        if (primeira.startsWith("match failed")) {
            for (int i = 1; i < linhas.length; i++) {
                String l = linhas[i].trim();
                if (!l.isEmpty() && !l.matches("=+")) {
                    primeira = primeira + ": " + limitar(l, 160);
                    break;
                }
            }
        }
        return List.of(primeira, "");
    }

    /**
     * Resume em uma linha as mensagens da validação de contrato (MensagensContrato):
     * tipo, operação e a primeira divergência. Retorna null se não for uma delas.
     */
    static String resumoContrato(String texto) {
        String[] l = texto.split("\\R");
        String titulo = null;
        String subtitulo = "";
        String primeira = null;
        String campo = null;
        int divergencias = 0;
        for (int i = 0; i < l.length; i++) {
            String t = l[i].trim();
            if (titulo == null && (t.equals("CONTRATO VIOLADO") || t.equals("SPEC INVÁLIDA") || t.equals("SPEC NÃO ENCONTRADA"))) {
                titulo = t;
                subtitulo = i + 1 < l.length ? l[i + 1].trim() : "";
            } else if (t.matches("\\[\\d+\\] .+")) {
                divergencias++;
                if (primeira == null) {
                    primeira = t.replaceFirst("\\[\\d+\\] ", "");
                }
            } else if (campo == null && primeira != null && (t.startsWith("Campo:") || t.startsWith("Local:"))) {
                campo = t.substring(t.indexOf(':') + 1).trim();
            }
        }
        if (titulo == null) {
            return null;
        }
        String operacao = subtitulo.split("\\s+\\|\\s+")[0];
        String status = subtitulo.contains("status ") ? subtitulo.replaceAll(".*status (\\d+).*", " (status $1)") : "";
        return switch (titulo) {
            case "CONTRATO VIOLADO" -> "Contrato violado em " + operacao + status + ": "
                    + (primeira != null ? primeira : "divergência") + (campo != null ? " em " + campo : "")
                    + (divergencias > 1 ? " (e mais " + (divergencias - 1) + " divergência(s))" : "");
            case "SPEC INVÁLIDA" -> "Spec inválida (" + subtitulo + "): "
                    + (primeira != null ? primeira : "") + (divergencias > 1 ? " (e mais " + (divergencias - 1) + " problema(s))" : "");
            default -> "Spec não encontrada: " + subtitulo;
        };
    }

    /** Causa em uma única linha (usada na tabela do resumo em Markdown). */
    static String motivo(String mensagem) {
        List<String> c = causaEOnde(mensagem);
        return c.get(1).isEmpty() ? c.get(0) : c.get(0) + " (em: " + c.get(1) + ")";
    }

    private static String limitar(String texto, int max) {
        return texto.length() > max ? texto.substring(0, max) + "..." : texto;
    }

    private static String duracao(long ms) {
        long segundos = Math.round(ms / 1000.0);
        return segundos < 60 ? segundos + " s" : (segundos / 60) + " min " + (segundos % 60) + " s";
    }

    private static String json(SuiteResult resultado, String ambiente, String momento) {
        return "{\n"
                + "  \"ambiente\": " + texto(ambiente) + ",\n"
                + "  \"total\": " + resultado.getScenarioCount() + ",\n"
                + "  \"passaram\": " + resultado.getScenarioPassedCount() + ",\n"
                + "  \"falharam\": " + resultado.getScenarioFailedCount() + ",\n"
                + "  \"duracaoMs\": " + resultado.getDurationMillis() + ",\n"
                + "  \"executadoEm\": " + texto(momento) + ",\n"
                + "  \"spec\": " + texto(infoSpec(ambiente)) + "\n"
                + "}\n";
    }

    private static String texto(String valor) {
        StringBuilder sb = new StringBuilder("\"");
        for (char c : valor.toCharArray()) {
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.append('"').toString();
    }

    private static String montar(SuiteResult resultado, String ambiente, String momento) {
        List<ScenarioResult> cenarios = new ArrayList<>();
        for (FeatureResult fr : resultado.getFeatureResults()) {
            cenarios.addAll(fr.getScenarioResults());
        }
        int falhas = resultado.getScenarioFailedCount();
        String amb = ambiente.toUpperCase(Locale.ROOT);

        StringBuilder md = new StringBuilder();
        md.append("## Testes de API - RH NET Social (").append(amb).append(")\n\n")
          .append(falhas == 0 ? "**Resultado: todos os cenários passaram.**\n\n"
                              : "**Resultado: " + falhas + " cenário(s) com falha.**\n\n")
          .append("| Cenários | Passaram | Falharam | Duração | Executado em |\n")
          .append("|---|---|---|---|---|\n")
          .append("| ").append(resultado.getScenarioCount())
          .append(" | ").append(resultado.getScenarioPassedCount())
          .append(" | ").append(falhas)
          .append(" | ").append(String.format(Locale.forLanguageTag("pt-BR"), "%.1f s", resultado.getDurationMillis() / 1000.0))
          .append(" | ").append(momento).append(" |\n\n")
          .append("Spec: ").append(infoSpec(ambiente)).append("\n\n")
          .append("### Cenários\n\n")
          .append("| Resultado | Funcionalidade | Cenário | Motivo da falha |\n")
          .append("|---|---|---|---|\n");

        for (ScenarioResult r : cenarios) {
            md.append("| ").append(r.isFailed() ? "❌ Falhou" : "✅ Passou")
              .append(" | ").append(celula(r.getScenario().getFeature().getName()))
              .append(" | ").append(celula(r.getScenario().getName()))
              .append(" | ").append(r.isFailed() ? celula(motivo(r.getFailureMessage())) : "")
              .append(" |\n");
        }
        md.append("\nO relatório completo desta execução é publicado no GitHub Pages (link abaixo).\n");
        return md.toString();
    }

    /** Primeira linha de spec/<ambiente>/INFO.md, que identifica a versão da spec em uso. */
    private static String infoSpec(String ambiente) {
        try {
            List<String> linhas = Files.readAllLines(Path.of("spec", ambiente, "INFO.md"), StandardCharsets.UTF_8);
            return linhas.isEmpty() ? "n/d" : linhas.get(0).trim();
        } catch (IOException e) {
            return "n/d";
        }
    }

    private static String primeiraLinha(String texto) {
        if (texto == null) {
            return "";
        }
        for (String linha : texto.split("\\R")) {
            String l = linha.trim();
            if (!l.isEmpty() && !l.matches("=+") && !l.equals("js failed:")) {
                return limitar(l, 200);
            }
        }
        return "";
    }

    private static String celula(String texto) {
        return texto == null ? "" : texto.replace("|", "\\|").replace("\n", " ");
    }
}
