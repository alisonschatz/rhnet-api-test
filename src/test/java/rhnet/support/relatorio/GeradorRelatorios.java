package rhnet.support.relatorio;

import com.intuit.karate.Results;
import com.intuit.karate.core.ScenarioResult;
import net.masterthought.cucumber.Configuration;
import net.masterthought.cucumber.ReportBuilder;
import rhnet.support.log.MascaradorLog;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Gera, ao final da execução, os relatórios complementares ao relatório do Karate:
 *
 *   target/cucumber-html-reports/overview-features.html   painel com gráficos e tendências
 *   target/resumo-execucao.md                              resumo em Markdown (exibido no GitHub Actions)
 *
 * Falhas na geração dos relatórios são registradas no console, mas nunca alteram o resultado dos testes.
 */
public final class GeradorRelatorios {

    private static final String PROJETO = "RH NET Social - Testes de API";
    private static final DateTimeFormatter DATA_HORA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss");

    private GeradorRelatorios() {
    }

    public static void gerar(Results results, String ambiente) {
        String momento = LocalDateTime.now().format(DATA_HORA);
        try {
            gerarPainel(results, ambiente, momento);
        } catch (Exception e) {
            System.err.println("Não foi possível gerar o painel de resultados: " + e.getMessage());
        }
        try {
            gerarResumo(results, ambiente, momento);
        } catch (Exception e) {
            System.err.println("Não foi possível gerar o resumo da execução: " + e.getMessage());
        }
    }

    // ------------------------------------------------------------------ painel

    private static void gerarPainel(Results results, String ambiente, String momento) throws IOException {
        List<String> jsons;
        try (Stream<Path> arquivos = Files.list(Path.of(results.getReportDir()))) {
            jsons = arquivos.map(Path::toString).filter(n -> n.endsWith(".json")).collect(Collectors.toList());
        }
        if (jsons.isEmpty()) {
            return;
        }
        Configuration config = new Configuration(new File("target"), PROJETO);
        config.setBuildNumber(ambiente.toUpperCase(Locale.ROOT) + " - " + momento);
        config.addClassifications("Ambiente", ambiente.toUpperCase(Locale.ROOT));
        config.addClassifications("Executado em", momento);
        String versao = System.getenv("VERSAO_IMPLANTADA");
        if (versao != null && !versao.isBlank()) {
            config.addClassifications("Versão implantada", versao);
        }
        config.addClassifications("Spec", infoSpec(ambiente));
        // Histórico das últimas 20 execuções deste ambiente (mantido enquanto a pasta target existir)
        config.setTrends(new File("target/tendencias-" + ambiente + ".json"), 20);
        new ReportBuilder(jsons, config).generateReports();
    }

    // ------------------------------------------------------------------ resumo

    private static void gerarResumo(Results results, String ambiente, String momento) throws IOException {
        List<ScenarioResult> cenarios = results.getScenarioResults().collect(Collectors.toList());
        long falhas = cenarios.stream().filter(ScenarioResult::isFailed).count();

        StringBuilder md = new StringBuilder();
        md.append("## Testes de API - RH NET Social (").append(ambiente.toUpperCase(Locale.ROOT)).append(")\n\n")
          .append(falhas == 0 ? "**Resultado: todos os cenários passaram.**\n\n"
                              : "**Resultado: " + falhas + " cenário(s) com falha.**\n\n")
          .append("| Cenários | Passaram | Falharam | Duração | Executado em |\n")
          .append("|---|---|---|---|---|\n")
          .append("| ").append(cenarios.size())
          .append(" | ").append(cenarios.size() - falhas)
          .append(" | ").append(falhas)
          .append(" | ").append(String.format(Locale.forLanguageTag("pt-BR"), "%.1f s", results.getElapsedTime() / 1000.0))
          .append(" | ").append(momento).append(" |\n\n")
          .append("Spec: ").append(infoSpec(ambiente)).append("\n\n");

        if (falhas > 0) {
            md.append("### Falhas\n\n");
            for (ScenarioResult r : cenarios) {
                if (!r.isFailed()) {
                    continue;
                }
                md.append("**").append(r.getScenario().getFeature().getName()).append("**  \n")
                  .append(r.getScenario().getName()).append("\n\n")
                  .append("<details><summary>Detalhe da falha</summary>\n\n~~~\n")
                  .append(limitar(MascaradorLog.mascarar(r.getErrorMessage()), 4000))
                  .append("\n~~~\n</details>\n\n");
            }
        }

        md.append("### Cenários\n\n")
          .append("| Resultado | Funcionalidade | Cenário |\n")
          .append("|---|---|---|\n");
        for (ScenarioResult r : cenarios) {
            md.append("| ").append(r.isFailed() ? "❌ Falhou" : "✅ Passou")
              .append(" | ").append(celula(r.getScenario().getFeature().getName()))
              .append(" | ").append(celula(r.getScenario().getName())).append(" |\n");
        }
        md.append("\nRelatórios completos: artefato **relatorio-").append(ambiente).append("** desta execução.\n");

        Files.writeString(Path.of("target", "resumo-execucao.md"), md.toString(), StandardCharsets.UTF_8);
    }

    // ------------------------------------------------------------- utilitários

    /** Primeira linha de spec/<ambiente>/INFO.md, que identifica a versão da spec em uso. */
    private static String infoSpec(String ambiente) {
        try {
            List<String> linhas = Files.readAllLines(Path.of("spec", ambiente, "INFO.md"), StandardCharsets.UTF_8);
            return linhas.isEmpty() ? "n/d" : linhas.get(0).trim();
        } catch (IOException e) {
            return "n/d";
        }
    }

    private static String limitar(String texto, int max) {
        if (texto == null) {
            return "";
        }
        return texto.length() <= max ? texto : texto.substring(0, max) + "\n... (mensagem truncada; ver relatório completo)";
    }

    private static String celula(String texto) {
        return texto == null ? "" : texto.replace("|", "\\|").replace("\n", " ");
    }
}
