package rhnet.support.auth;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * Utilitários de autenticação usados pelo login e pelos testes da API de auth.
 *
 * Uso no Karate:
 *   * def Auth = Java.type('rhnet.support.auth.Autenticacao')
 *   * header Authorization = 'Basic ' + Auth.basic(parceiroToken, clienteToken)
 */
public final class Autenticacao {

    private Autenticacao() {
    }

    /** Credenciais no formato do cabeçalho Basic Auth (usuario:senha em Base64). */
    public static String basic(String usuario, String senha) {
        String credenciais = usuario + ":" + senha;
        return Base64.getEncoder().encodeToString(credenciais.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Payload (claims) do JWT como texto JSON, sem validar a assinatura.
     * Usado para obter dados da sessão do usuário de teste, como sistemaId e empresas vinculadas.
     */
    public static String payloadJwt(String token) {
        if (token == null) {
            throw new IllegalArgumentException("Token nulo");
        }
        String[] partes = token.split("\\.");
        if (partes.length != 3) {
            throw new IllegalArgumentException("Token não está no formato JWT (header.payload.assinatura)");
        }
        return new String(Base64.getUrlDecoder().decode(partes[1]), StandardCharsets.UTF_8);
    }
}
