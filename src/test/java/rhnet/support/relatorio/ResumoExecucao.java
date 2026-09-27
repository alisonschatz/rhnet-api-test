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
import java.util.List;
import java.util.Locale;

/**
 * Gera, ao final da execução:
 *   target/resumo-execucao.md    tabela de resultados em português, exibida no GitHub Actions
 *   target/resumo-execucao.json  números da execução, usados na página inicial publicada
 * Falhas na geração nunca alteram o resultado dos testes.
 *
 * Por segurança, o resumo traz apenas a primeira linha de cada falha (sem corpos de resposta):
 * o detalhe completo, com dados mascarados, fica nos relatórios Allure e Karate.
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
        } catch (Exception e) {
            System.err.println("Não foi possível gerar o resumo da execução: " + e.getMessage());
        }
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
              .append(" | ").append(r.isFailed() ? celula(primeiraLinha(r.getFailureMessage())) : "")
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
            if (!l.isEmpty() && !l.matches("=+")) {
                return l.length() > 200 ? l.substring(0, 200) + "..." : l;
            }
        }
        return "";
    }

    private static String celula(String texto) {
        return texto == null ? "" : texto.replace("|", "\\|").replace("\n", " ");
    }
}
