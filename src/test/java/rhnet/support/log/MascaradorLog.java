package rhnet.support.log;

import com.intuit.karate.http.HttpLogModifier;

import java.util.regex.Pattern;

/**
 * Mascara dados sensíveis (LGPD) em logs e relatórios do Karate:
 * cabeçalho Authorization, tokens e campos pessoais em JSON.
 * Para mascarar um novo campo, inclua o nome em CAMPOS_SENSIVEIS.
 */
public class MascaradorLog implements HttpLogModifier {

    public static final HttpLogModifier INSTANCE = new MascaradorLog();

    private static final String CAMPOS_SENSIVEIS =
            "token|cpf|pis|nis|rg|cnh|ctps|titulo_eleitor|salario|remuneracao|conta|senha";

    private static final Pattern JSON_SENSIVEL = Pattern.compile(
            "(\"(?:" + CAMPOS_SENSIVEIS + ")\"\\s*:\\s*)(\"[^\"]*\"|\\d+(?:\\.\\d+)?)",
            Pattern.CASE_INSENSITIVE);

    private static final Pattern QUERY_SENSIVEL = Pattern.compile(
            "([?&](?:" + CAMPOS_SENSIVEIS + ")=)[^&]*", Pattern.CASE_INSENSITIVE);

    @Override
    public boolean enableForUri(String uri) {
        return true;
    }

    @Override
    public String uri(String uri) {
        return uri == null ? null : QUERY_SENSIVEL.matcher(uri).replaceAll("$1***");
    }

    @Override
    public String header(String header, String value) {
        if (header != null && header.equalsIgnoreCase("Authorization") && value != null) {
            int espaco = value.indexOf(' ');
            return espaco > 0 ? value.substring(0, espaco) + " ***" : "***";
        }
        return value;
    }

    @Override
    public String request(String uri, String request) {
        return mascarar(request);
    }

    @Override
    public String response(String uri, String response) {
        return mascarar(response);
    }

    /** Mascara dados sensíveis em qualquer texto (usado também nos relatórios). */
    public static String mascarar(String corpo) {
        return corpo == null ? null : JSON_SENSIVEL.matcher(corpo).replaceAll("$1\"***\"");
    }
}
