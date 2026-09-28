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
 *   target/resumo-console.txt    resumo curto exibido no terminal
 *
 * As falhas são separadas em NOVAS e CONHECIDAS (problemas-conhecidos.json): só as novas
 * fazem a execução falhar. Falhas na geração dos resumos nunca alteram o resultado dos testes.
 */
public final class ResumoExecucao {

    private static final DateTimeFormatter DATA_HORA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final ZoneId FUSO = ZoneId.of("America/Sao_Paulo");

    /** Um cenário com falha, já classificado. */
    private record Falha(String funcionalidade, String cenario, String mensagem, ProblemasConhecidos.Problema conhecido) {
        String nomeCompleto() {
            return funcionalidade + ": " + cenario;
        }
    }

    private ResumoExecucao() {
    }

    // =================================================================== API pública

    public static void gerar(SuiteResult resultado, String ambiente) {
        String momento = ZonedDateTime.now(FUSO).format(DATA_HORA);
        try {
            List<Falha> falhas = falhas(resultado, ambiente);
            Files.createDirectories(Path.of("target"));
            Files.writeString(Path.of("target", "resumo-execucao.md"), markdown(resultado, ambiente, momento, falhas), StandardCharsets.UTF_8);
            Files.writeString(Path.of("target", "resumo-execucao.json"), json(resultado, ambiente, momento, falhas), StandardCharsets.UTF_8);
            Files.writeString(Path.of("target", "resumo-console.txt"), console(resultado, ambiente, falhas), StandardCharsets.UTF_8);
        } catch (Exception e) {
            System.err.println("Não foi possível gerar o resumo da execução: " + e.getMessage());
        }
    }

    /** Resumo curto para o terminal. */
    public static String console(SuiteResult resultado, String ambiente) {
        return console(resultado, ambiente, falhas(resultado, ambiente));
    }

    /** Quantidade de falhas NOVAS (não registradas em problemas-conhecidos.json). */
    public static int falhasNovas(SuiteResult resultado, String ambiente) {
        return (int) falhas(resultado, ambiente).stream().filter(f -> f.conhecido() == null).count();
    }

    // =================================================================== classificação

    private static List<Falha> falhas(SuiteResult resultado, String ambiente) {
        ProblemasConhecidos conhecidos = ProblemasConhecidos.carregar(ambiente);
        List<Falha> lista = new ArrayList<>();
        for (FeatureResult fr : resultado.getFeatureResults()) {
            for (ScenarioResult r : fr.getScenarioResults()) {
                if (r.isFailed()) {
                    String msg = r.getFailureMessage();
                    lista.add(new Falha(r.getScenario().getFeature().getName(), r.getScenario().getName(), msg,
                            conhecidos.identificar(msg)));
                }
            }
        }
        return lista;
    }

    // =================================================================== console

    private static String console(SuiteResult resultado, String ambiente, List<Falha> falhas) {
        int total = resultado.getScenarioCount();
        List<Falha> novas = falhas.stream().filter(f -> f.conhecido() == null).toList();
        List<Falha> conhecidas = falhas.stream().filter(f -> f.conhecido() != null).toList();

        StringBuilder sb = new StringBuilder();
        sb.append("Resultado em ").append(ambiente.toUpperCase(Locale.ROOT)).append(": ")
          .append(resultado.getScenarioPassedCount()).append(" de ").append(total).append(" cenários passaram");
        if (!falhas.isEmpty()) {
            sb.append(" | ").append(falhas.size()).append(" falharam");
            if (!conhecidas.isEmpty()) {
                sb.append(" (").append(novas.size()).append(novas.size() == 1 ? " nova, " : " novas, ")
                  .append(conhecidas.size()).append(conhecidas.size() == 1 ? " conhecida)" : " conhecidas)");
            }
        }
        sb.append(" | ").append(duracao(resultado.getDurationMillis())).append("\n");

        if (!novas.isEmpty()) {
            Map<List<String>, List<String>> porCausa = new LinkedHashMap<>();
            for (Falha f : novas) {
                porCausa.computeIfAbsent(causaEOnde(f.mensagem()), k -> new ArrayList<>()).add(f.nomeCompleto());
            }
            sb.append("\nFalhas novas (").append(porCausa.size()).append(porCausa.size() == 1 ? " causa" : " causas").append("):\n");
            if (porCausa.size() == 1 && novas.size() == total && total > 1) {
                sb.append("  Todos os cenários falharam pelo mesmo motivo: indica problema de configuração\n")
                  .append("  ou de ambiente, não da API. Veja a causa abaixo.\n");
            }
            boolean todos = porCausa.size() == 1 && novas.size() == total && total > 1;
            int exibidas = 0;
            for (Map.Entry<List<String>, List<String>> causa : porCausa.entrySet()) {
                if (exibidas++ == 15) {
                    sb.append("\n  ... e mais ").append(porCausa.size() - 15).append(" causa(s) (veja o relatório)\n");
                    break;
                }
                escreverCausa(sb, causa.getKey().get(0), causa.getKey().get(1), causa.getValue(), !todos);
            }
        }

        if (!conhecidas.isEmpty()) {
            Map<ProblemasConhecidos.Problema, Integer> porProblema = new LinkedHashMap<>();
            for (Falha f : conhecidas) {
                porProblema.merge(f.conhecido(), 1, Integer::sum);
            }
            sb.append("\nFalhas conhecidas (já reportadas, não fazem a execução falhar):\n");
            for (Map.Entry<ProblemasConhecidos.Problema, Integer> p : porProblema.entrySet()) {
                sb.append("  - ").append(p.getKey().id()).append(": ").append(p.getKey().descricao())
                  .append(" (").append(p.getValue()).append(p.getValue() == 1 ? " cenário)" : " cenários)").append("\n");
            }
        }
        return sb.toString();
    }

    private static void escreverCausa(StringBuilder sb, String motivo, String onde, List<String> cenarios, boolean listarCenarios) {
        String recuo = "\n      ";
        sb.append("\n");
        if (cenarios.size() == 1) {
            sb.append("  - ").append(cenarios.get(0)).append(recuo).append(motivo.replace("\n", recuo)).append("\n");
        } else {
            sb.append("  - ").append(motivo.replace("\n", "\n    ")).append("\n");
        }
        if (!onde.isEmpty()) {
            sb.append("      Onde: ").append(onde).append("\n");
        }
        if (cenarios.size() > 1 && listarCenarios) {
            sb.append("      ").append(cenarios.size()).append(" cenários, entre eles:\n");
            for (int i = 0; i < Math.min(3, cenarios.size()); i++) {
                sb.append("        ").append(cenarios.get(i)).append("\n");
            }
        }
    }

    // =================================================================== causa da falha

    /**
     * Causa de uma falha e onde ela ocorreu (quando informado).
     * - Erros de JavaScript do Karate ("js failed:"): usa o bloco "Error:" e o "Code:" mais internos.
     * - Falhas do callSingle: remove o prefixo técnico "callSingle failed: <caminho> -".
     * - Falhas de status: remove o tempo de resposta e a URL, que já estão no relatório.
     * - Falhas de match: acrescenta a linha que descreve a divergência.
     */
    static List<String> causaEOnde(String mensagem) {
        if (mensagem == null || mensagem.isBlank()) {
            return List.of("Falha sem mensagem (veja o relatório)", "");
        }
        String[] linhas = mensagem.split("\\R");

        // Erros podem vir aninhados (ex.: falha dentro de um callSingle do karate-config.js):
        // o bloco "Error:" mais interno, o último da mensagem, é o que contém a causa real
        String codigo = "";
        StringBuilder erro = null;
        for (int i = 0; i < linhas.length; i++) {
            String l = linhas[i].trim();
            if (l.startsWith("Code:")) {
                codigo = limitar(l.substring(5).trim(), 100);
            } else if (l.startsWith("Error:")) {
                erro = new StringBuilder(l.substring(6).trim());
                for (int j = i + 1; j < linhas.length && !linhas[j].trim().equals("=========="); j++) {
                    erro.append('\n').append(linhas[j]);
                }
            }
        }
        if (erro != null) {
            String texto = erro.toString().trim().replaceFirst("^callSingle failed: \\S+ - ", "");
            // Falhas geradas pelo próprio projeto (karate.fail) já explicam a causa: o código não ajuda
            String onde = codigo.contains("karate.fail(") || codigo.contains("callSingle(") ? "" : codigo;
            String contrato = resumoContrato(texto);
            if (contrato != null) {
                return List.of(contrato, "");
            }
            return List.of(linhasUteis(texto, 15), onde);
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

    /** Resume em uma linha as mensagens da validação de contrato (MensagensContrato), ou null. */
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

    /** Causa em uma única linha (tabela do resumo em Markdown). */
    static String motivo(String mensagem) {
        List<String> c = causaEOnde(mensagem);
        String m = c.get(0).replace("\n", " ");
        return c.get(1).isEmpty() ? m : m + " (em: " + c.get(1) + ")";
    }

    // =================================================================== markdown e json

    private static String markdown(SuiteResult resultado, String ambiente, String momento, List<Falha> falhas) {
        long novas = falhas.stream().filter(f -> f.conhecido() == null).count();
        long conhecidas = falhas.size() - novas;
        StringBuilder md = new StringBuilder();
        md.append("## Testes de API - RH NET Social (").append(ambiente.toUpperCase(Locale.ROOT)).append(")\n\n")
          .append(novas == 0 ? (conhecidas == 0 ? "**Resultado: todos os cenários passaram.**\n\n"
                                               : "**Resultado: sem falhas novas** (" + conhecidas + " falha(s) conhecida(s)).\n\n")
                             : "**Resultado: " + novas + " falha(s) nova(s)**" + (conhecidas > 0 ? " e " + conhecidas + " conhecida(s)." : ".") + "\n\n")
          .append("| Cenários | Passaram | Falhas novas | Falhas conhecidas | Duração | Executado em |\n")
          .append("|---|---|---|---|---|---|\n")
          .append("| ").append(resultado.getScenarioCount())
          .append(" | ").append(resultado.getScenarioPassedCount())
          .append(" | ").append(novas)
          .append(" | ").append(conhecidas)
          .append(" | ").append(duracao(resultado.getDurationMillis()))
          .append(" | ").append(momento).append(" |\n\n")
          .append("Spec: ").append(infoSpec(ambiente)).append("\n\n");

        if (!falhas.isEmpty()) {
            md.append("### Falhas\n\n")
              .append("| Tipo | Funcionalidade | Cenário | Motivo |\n")
              .append("|---|---|---|---|\n");
            for (Falha f : falhas) {
                md.append("| ").append(f.conhecido() == null ? "❌ Nova" : "⚠️ Conhecida (" + celula(f.conhecido().id()) + ")")
                  .append(" | ").append(celula(f.funcionalidade()))
                  .append(" | ").append(celula(f.cenario()))
                  .append(" | ").append(celula(motivo(f.mensagem()))).append(" |\n");
            }
            md.append("\n");
        }
        md.append("O relatório completo desta execução é publicado no GitHub Pages (link abaixo).\n");
        return md.toString();
    }

    private static String json(SuiteResult resultado, String ambiente, String momento, List<Falha> falhas) {
        long novas = falhas.stream().filter(f -> f.conhecido() == null).count();
        return "{\n"
                + "  \"ambiente\": " + texto(ambiente) + ",\n"
                + "  \"total\": " + resultado.getScenarioCount() + ",\n"
                + "  \"passaram\": " + resultado.getScenarioPassedCount() + ",\n"
                + "  \"falharam\": " + falhas.size() + ",\n"
                + "  \"falhasNovas\": " + novas + ",\n"
                + "  \"falhasConhecidas\": " + (falhas.size() - novas) + ",\n"
                + "  \"duracaoMs\": " + resultado.getDurationMillis() + ",\n"
                + "  \"executadoEm\": " + texto(momento) + ",\n"
                + "  \"spec\": " + texto(infoSpec(ambiente)) + "\n"
                + "}\n";
    }

    // =================================================================== utilitários

    private static String infoSpec(String ambiente) {
        try {
            List<String> linhas = Files.readAllLines(Path.of("spec", ambiente, "INFO.md"), StandardCharsets.UTF_8);
            return linhas.isEmpty() ? "n/d" : linhas.get(0).trim();
        } catch (IOException e) {
            return "n/d";
        }
    }

    private static String duracao(long ms) {
        long segundos = Math.round(ms / 1000.0);
        return segundos < 60 ? segundos + " s" : (segundos / 60) + " min " + (segundos % 60) + " s";
    }

    /** Até "max" linhas não vazias do texto, cada uma limitada. */
    private static String linhasUteis(String texto, int max) {
        List<String> uteis = new ArrayList<>();
        for (String l : texto.split("\\R")) {
            String t = l.trim();
            if (!t.isEmpty() && !t.matches("=+")) {
                if (uteis.size() == max) {
                    uteis.add("... (veja o relatório)");
                    break;
                }
                uteis.add(limitar(t, 220));
            }
        }
        return String.join("\n", uteis);
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

    private static String limitar(String texto, int max) {
        return texto.length() > max ? texto.substring(0, max) + "..." : texto;
    }

    private static String celula(String texto) {
        return texto == null ? "" : texto.replace("|", "\\|").replace("\n", " ");
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
}
