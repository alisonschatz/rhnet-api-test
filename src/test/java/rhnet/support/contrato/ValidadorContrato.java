package rhnet.support.contrato;

import com.atlassian.oai.validator.OpenApiInteractionValidator;
import com.atlassian.oai.validator.model.Request;
import com.atlassian.oai.validator.model.SimpleResponse;
import com.atlassian.oai.validator.report.LevelResolver;
import com.atlassian.oai.validator.report.ValidationReport;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Valida respostas HTTP contra as specs oficiais do projeto:
 *
 *   spec/<ambiente>/<api>.json     ex.: spec/hml/rhnetsocial.json, spec/prd/rhnetsocial.json
 *
 * As specs são baixadas, validadas e versionadas manualmente pelo QA.
 * Exceções aceitas pelo time ficam em src/test/resources/contrato-ignorar.txt.
 * As mensagens de erro são montadas em português por MensagensContrato.
 */
public final class ValidadorContrato {

    /** Validador pronto ou a mensagem explicando por que não foi possível criá-lo. */
    private record Spec(OpenApiInteractionValidator validator, String erro) {
    }

    private static final Map<String, Spec> SPECS = new ConcurrentHashMap<>();

    private ValidadorContrato() {
    }

    /** Retorna "" se a resposta está no contrato, ou a mensagem explicando o problema. */
    public static String validate(String ambiente, String api, String method, String url, int status, byte[] body) {
        Path arquivo = Path.of("spec", ambiente, api + ".json");
        String nome = "spec/" + ambiente + "/" + api + ".json";
        Spec spec = SPECS.computeIfAbsent(nome, k -> carregar(arquivo, nome));
        if (spec.erro() != null) {
            return spec.erro();
        }
        String path = URI.create(url).getPath();
        try {
            SimpleResponse.Builder resposta = SimpleResponse.Builder.status(status)
                    .withHeader("Content-Type", "application/json");
            if (body != null && body.length > 0) {
                resposta.withBody(new String(body, StandardCharsets.UTF_8));
            }
            ValidationReport report = spec.validator().validateResponse(
                    path, Request.Method.valueOf(method.toUpperCase()), resposta.build());

            List<String[]> violacoes = new ArrayList<>();
            for (ValidationReport.Message m : report.getMessages()) {
                if (m.getLevel() == ValidationReport.Level.ERROR) {
                    violacoes.add(new String[]{m.getKey(), m.getMessage()});
                }
            }
            return violacoes.isEmpty()
                    ? ""
                    : MensagensContrato.respostaForaDoContrato(nome, method, path, status, violacoes);
        } catch (Exception e) {
            return "Erro inesperado ao validar " + method + " " + path + " contra " + nome + ": " + e.getMessage();
        }
    }

    private static Spec carregar(Path arquivo, String nome) {
        if (!Files.exists(arquivo)) {
            return new Spec(null, MensagensContrato.specNaoEncontrada(nome));
        }
        String conteudo = null;
        try {
            conteudo = Files.readString(arquivo, StandardCharsets.UTF_8);
            LevelResolver.Builder niveis = LevelResolver.create();
            for (String chave : chavesIgnoradas()) {
                niveis.withLevel(chave, ValidationReport.Level.IGNORE);
            }
            OpenApiInteractionValidator validator = OpenApiInteractionValidator
                    .createForInlineApiSpecification(conteudo)
                    .withLevelResolver(niveis.build())
                    .build();
            return new Spec(validator, null);
        } catch (Exception e) {
            String erroTecnico = e.getMessage() == null ? e.toString() : e.getMessage();
            return new Spec(null, MensagensContrato.specInvalida(nome, erroTecnico, conteudo));
        }
    }

    private static List<String> chavesIgnoradas() throws Exception {
        List<String> chaves = new ArrayList<>();
        InputStream in = ValidadorContrato.class.getClassLoader().getResourceAsStream("contrato-ignorar.txt");
        if (in == null) {
            return chaves;
        }
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String linha;
            while ((linha = reader.readLine()) != null) {
                linha = linha.trim();
                if (!linha.isEmpty() && !linha.startsWith("#")) {
                    chaves.add(linha);
                }
            }
        }
        return chaves;
    }
}
