package rhnet.support.relatorio;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Falhas já reportadas aos devs, declaradas em problemas-conhecidos.json (raiz do projeto).
 * Uma falha é "conhecida" quando a mensagem de erro contém o trecho (ou casa com a expressão
 * regular) de alguma entrada válida para o ambiente em execução.
 * O mesmo arquivo alimenta o filtro "Resolution" do relatório Allure (allurerc.mjs).
 */
public final class ProblemasConhecidos {

    public record Problema(String id, String descricao, Pattern mensagemDoErro, String link) {
    }

    private final List<Problema> problemas;

    private ProblemasConhecidos(List<Problema> problemas) {
        this.problemas = problemas;
    }

    public static ProblemasConhecidos carregar(String ambiente) {
        List<Problema> lista = new ArrayList<>();
        Path arquivo = Path.of("problemas-conhecidos.json");
        if (!Files.exists(arquivo)) {
            return new ProblemasConhecidos(lista);
        }
        try {
            JsonNode raiz = new ObjectMapper().readTree(arquivo.toFile());
            for (JsonNode p : raiz.path("problemas")) {
                boolean doAmbiente = !p.has("ambientes");
                for (JsonNode a : p.path("ambientes")) {
                    doAmbiente |= a.asText().equalsIgnoreCase(ambiente);
                }
                String trecho = p.path("mensagemDoErro").asText("");
                if (doAmbiente && !trecho.isBlank()) {
                    lista.add(new Problema(p.path("id").asText("sem id"), p.path("descricao").asText(""),
                            Pattern.compile(trecho), p.path("link").asText("")));
                }
            }
        } catch (Exception e) {
            System.err.println("problemas-conhecidos.json inválido; nenhuma falha será tratada como conhecida: " + e.getMessage());
            lista.clear();
        }
        return new ProblemasConhecidos(lista);
    }

    /** O problema conhecido correspondente à mensagem de falha, ou null se a falha for nova. */
    public Problema identificar(String mensagem) {
        if (mensagem == null) {
            return null;
        }
        for (Problema p : problemas) {
            if (p.mensagemDoErro().matcher(mensagem).find()) {
                return p;
            }
        }
        return null;
    }
}
