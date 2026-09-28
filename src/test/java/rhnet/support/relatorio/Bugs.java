package rhnet.support.relatorio;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import io.karatelabs.core.FeatureResult;
import io.karatelabs.core.ScenarioResult;
import io.karatelabs.core.SuiteResult;
import io.karatelabs.gherkin.Scenario;
import io.karatelabs.gherkin.Tag;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

/**
 * Bugs já reportados, marcados no próprio cenário com a tag @bug-<chamado>:
 *
 *   @regressao @bug-RHNET-123
 *   Scenario: Consulta sem token de acesso é rejeitada (401)
 *
 * Um cenário com @bug-... que falha é uma falha CONHECIDA: aparece nos relatórios, mas não
 * reprova a execução. Se ele passar, o bug provavelmente foi corrigido e a tag deve ser removida.
 */
public final class Bugs {

    private static final String PREFIXO = "bug-";

    private Bugs() {
    }

    /** Chamados das tags @bug-... do cenário (inclui tags da feature). Vazio se não houver. */
    public static List<String> chamados(Scenario cenario) {
        List<String> ids = new ArrayList<>();
        for (Tag tag : cenario.getTagsEffective()) {
            String texto = tag.getText();
            if (texto != null && texto.startsWith(PREFIXO) && texto.length() > PREFIXO.length()) {
                ids.add(texto.substring(PREFIXO.length()));
            }
        }
        return ids;
    }

    /**
     * Repassa as tags @bug-... para os resultados do Allure (target/allure-results), que não as
     * recebem do allure-karate. Com isso, os cenários entram na categoria "Falhas conhecidas".
     * Cada resultado é localizado pelo nome do cenário e pela linha dele na feature.
     */
    public static void marcarNoAllure(SuiteResult resultado) {
        record Marcacao(String nome, int linha, List<String> chamados) {
        }
        List<Marcacao> marcacoes = new ArrayList<>();
        for (FeatureResult fr : resultado.getFeatureResults()) {
            for (ScenarioResult r : fr.getScenarioResults()) {
                List<String> ids = chamados(r.getScenario());
                if (!ids.isEmpty()) {
                    marcacoes.add(new Marcacao(r.getScenario().getName().trim(), r.getScenario().getLine(), ids));
                }
            }
        }
        Path pasta = Path.of("target", "allure-results");
        if (marcacoes.isEmpty() || !Files.isDirectory(pasta)) {
            return;
        }
        ObjectMapper json = new ObjectMapper();
        try (Stream<Path> arquivos = Files.list(pasta)) {
            for (Path arquivo : arquivos.filter(p -> p.toString().endsWith("-result.json")).toList()) {
                ObjectNode teste = (ObjectNode) json.readTree(arquivo.toFile());
                String nome = teste.path("name").asText("").trim();
                String fullName = teste.path("fullName").asText("");
                for (Marcacao m : marcacoes) {
                    if (m.nome().equals(nome) && fullName.endsWith(":" + m.linha())) {
                        ArrayNode labels = teste.has("labels") ? (ArrayNode) teste.get("labels") : teste.putArray("labels");
                        for (String id : m.chamados()) {
                            labels.addObject().put("name", "tag").put("value", PREFIXO + id);
                        }
                        json.writeValue(new File(arquivo.toString()), teste);
                        break;
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("Não foi possível marcar os bugs conhecidos no relatório Allure: " + e.getMessage());
        }
    }
}
