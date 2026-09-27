package rhnet.support.contrato;

import java.util.ArrayList;
import java.util.List;

/**
 * Leitor de JSON mínimo que registra, para cada chave do arquivo, o caminho completo
 * e o número da linha. Serve para apontar exatamente onde está um problema na spec.
 * Sem dependências externas.
 */
final class LocalizadorJson {

    /** Uma chave encontrada no arquivo: caminho até ela (inclusive) e linha onde aparece. */
    record Chave(List<String> caminho, int linha) {
        String ultimo() {
            return caminho.get(caminho.size() - 1);
        }

        boolean dentroDe(List<String> prefixo) {
            return caminho.size() > prefixo.size() && caminho.subList(0, prefixo.size()).equals(prefixo);
        }
    }

    private final String texto;
    private final String[] linhas;
    private final List<Chave> chaves = new ArrayList<>();
    private int pos;
    private int linha = 1;

    LocalizadorJson(String texto) {
        this.texto = texto;
        this.linhas = texto.split("\\R", -1);
        try {
            valor(new ArrayList<>());
        } catch (RuntimeException e) {
            // JSON malformado: o localizador simplesmente fica com o que conseguiu ler
        }
    }

    List<Chave> chaves() {
        return chaves;
    }

    /** Conteúdo da linha (1-based), sem espaços nas pontas. */
    String linha(int numero) {
        return numero >= 1 && numero <= linhas.length ? linhas[numero - 1].trim() : "";
    }

    /** Linhas que contêm o trecho informado. */
    List<Integer> linhasCom(String trecho) {
        List<Integer> r = new ArrayList<>();
        for (int i = 0; i < linhas.length; i++) {
            if (linhas[i].contains(trecho)) {
                r.add(i + 1);
            }
        }
        return r;
    }

    Chave buscar(List<String> caminho) {
        for (Chave c : chaves) {
            if (c.caminho().equals(caminho)) {
                return c;
            }
        }
        return null;
    }

    // ------------------------------------------------------------- parser

    private void valor(List<String> caminho) {
        espacos();
        char c = texto.charAt(pos);
        if (c == '{') {
            objeto(caminho);
        } else if (c == '[') {
            lista(caminho);
        } else if (c == '"') {
            lerTexto();
        } else {
            while (pos < texto.length() && ",}] \t\r\n".indexOf(texto.charAt(pos)) < 0) {
                pos++;
            }
        }
    }

    private void objeto(List<String> caminho) {
        pos++;
        while (true) {
            espacos();
            if (texto.charAt(pos) == '}') {
                pos++;
                return;
            }
            int linhaDaChave = linha;
            String chave = lerTexto();
            List<String> filho = new ArrayList<>(caminho);
            filho.add(chave);
            chaves.add(new Chave(filho, linhaDaChave));
            espacos();
            pos++; // ':'
            valor(filho);
            espacos();
            if (texto.charAt(pos) == ',') {
                pos++;
            }
        }
    }

    private void lista(List<String> caminho) {
        pos++;
        int indice = 0;
        while (true) {
            espacos();
            if (texto.charAt(pos) == ']') {
                pos++;
                return;
            }
            List<String> item = new ArrayList<>(caminho);
            item.add("[" + indice++ + "]");
            valor(item);
            espacos();
            if (texto.charAt(pos) == ',') {
                pos++;
            }
        }
    }

    private String lerTexto() {
        StringBuilder sb = new StringBuilder();
        pos++; // aspas de abertura
        while (texto.charAt(pos) != '"') {
            char c = texto.charAt(pos);
            if (c == '\\') {
                pos++;
                c = texto.charAt(pos);
            }
            if (c == '\n') {
                linha++;
            }
            sb.append(c);
            pos++;
        }
        pos++; // aspas de fechamento
        return sb.toString();
    }

    private void espacos() {
        while (pos < texto.length() && Character.isWhitespace(texto.charAt(pos))) {
            if (texto.charAt(pos) == '\n') {
                linha++;
            }
            pos++;
        }
    }
}
