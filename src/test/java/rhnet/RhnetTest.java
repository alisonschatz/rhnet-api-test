package rhnet;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Ponto único de execução, sempre em paralelo.
 *
 *   ./mvnw test                                  -> tudo, em HML
 *   ./mvnw test -Dkarate.env=prd                 -> tudo, em PRD
 *   ./mvnw test -Dkarate.env=prd -Dtags=@smoke   -> só smoke, em PRD
 *   ./mvnw test -Dtags=@smoke,@regressao         -> smoke OU regressao
 */
class RhnetTest {

    @Test
    void executar() {
        String ambiente = System.getProperty("karate.env", "hml");
        String tags = System.getProperty("tags", "").trim();
        int threads = Integer.getInteger("threads", 5);

        Runner.Builder<?> runner = Runner.path("classpath:rhnet/features")
                .karateEnv(ambiente)
                .outputCucumberJson(true)
                .outputJunitXml(true);
        if (!tags.isEmpty()) {
            runner.tags(tags);
        }

        Results results = runner.parallel(threads);
        assertEquals(0, results.getFailCount(), results.getErrorMessages());
    }
}
