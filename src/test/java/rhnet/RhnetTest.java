package rhnet;

import io.karatelabs.core.Runner;
import io.karatelabs.core.SuiteResult;
import io.qameta.allure.karate.AllureKarate;
import org.junit.jupiter.api.Test;
import rhnet.support.relatorio.ResumoExecucao;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Ponto único de execução, sempre em paralelo.
 *
 *   ./mvnw test                                  -> tudo, em HML
 *   ./mvnw test -Dkarate.env=prd                 -> tudo, em PRD
 *   ./mvnw test -Dkarate.env=prd -Dtags=@smoke   -> só smoke, em PRD
 *   ./mvnw test -Dtags=@smoke,@regressao         -> smoke OU regressao
 *
 * Relatórios gerados:
 *   target/karate-reports/karate-summary.html   detalhe técnico (Karate)
 *   target/allure-results/                       dados do Allure (./mvnw allure:report gera o HTML)
 *   target/resumo-execucao.md                    resumo exibido no GitHub Actions
 */
class RhnetTest {

    @Test
    void executar() throws IOException {
        String ambiente = System.getProperty("karate.env", "hml");
        String tags = System.getProperty("tags", "").trim();
        int threads = Integer.getInteger("threads", 5);

        // Cada execução gera um relatório Allure próprio, sem resultados de execuções anteriores
        limpar(Path.of("target", "allure-results"));

        Runner.Builder runner = Runner.path("classpath:rhnet/features")
                .karateEnv(ambiente)
                // O relatório do Karate é substituído a cada execução; o histórico fica no Allure
                .backupOutputDir(false)
                // O console mostra só o resumo abaixo; o detalhe de cada cenário fica nos relatórios
                .outputConsoleSummary(false)
                .listener(new AllureKarate());
        if (!tags.isEmpty()) {
            runner.tags(tags);
        }

        SuiteResult resultado = runner.parallel(threads);
        ResumoExecucao.gerar(resultado, ambiente);
        // Os scripts rodar exibem o resumo por conta própria (-Drodar=true); IDE e pipeline, aqui
        if (!Boolean.getBoolean("rodar")) {
            System.out.println();
            System.out.println(ResumoExecucao.console(resultado, ambiente));
        }
        int falhas = resultado.getScenarioFailedCount();
        assertEquals(0, falhas, falhas + " cenário(s) falharam. Detalhes nos relatórios Allure e Karate.");
    }

    private static void limpar(Path pasta) throws IOException {
        if (!Files.exists(pasta)) {
            return;
        }
        try (Stream<Path> arquivos = Files.walk(pasta)) {
            arquivos.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
        }
    }
}
