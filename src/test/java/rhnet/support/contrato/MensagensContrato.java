package rhnet.support.contrato;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Monta as mensagens da validação de contrato exibidas no relatório.
 * Formato técnico e neutro, lido por QA e desenvolvimento: o que diverge, onde e qual a correção
 * esperada. Ocorrências repetidas da mesma divergência (ex.: o mesmo campo em todos os itens de
 * uma lista) são agrupadas em uma única entrada.
 */
public final class MensagensContrato {

    private static final String LINHA = "============================================================";

    private MensagensContrato() {
    }

    // =================================================================== spec ausente

    public static String specNaoEncontrada(String arquivo) {
        return cabecalho("SPEC NÃO ENCONTRADA", arquivo)
                + "O arquivo de spec não existe. Nenhuma resposta foi validada contra ele.\n\n"
                + campo("Correção", "adicionar o arquivo, conforme a seção \"Atualizando as specs\" do README.")
                + LINHA;
    }

    // =================================================================== spec inválida

    /**
     * @param erroTecnico  mensagem original do carregador de specs
     * @param conteudoSpec texto do arquivo, usado para localizar linha e caminho exatos (pode ser nulo)
     */
    public static String specInvalida(String arquivo, String erroTecnico, String conteudoSpec) {
        List<String> problemas = new ArrayList<>();
        for (String linha : erroTecnico.split("\\R")) {
            Matcher m = Pattern.compile("^\\s*-\\s*(.+)$").matcher(linha);
            if (m.matches()) {
                problemas.add(m.group(1).trim());
            }
        }
        if (problemas.isEmpty()) {
            problemas.add(erroTecnico.trim());
        }
        LocalizadorJson spec = conteudoSpec == null ? null : new LocalizadorJson(conteudoSpec);

        StringBuilder sb = new StringBuilder(cabecalho("SPEC INVÁLIDA", arquivo));
        sb.append("O arquivo não está em conformidade com a especificação OpenAPI e não pôde ser carregado.\n")
          .append("Nenhuma resposta foi validada contra ele.\n")
          .append(problemas.size()).append(problemas.size() == 1 ? " problema encontrado.\n" : " problemas encontrados.\n");
        int n = 1;
        for (String p : problemas) {
            sb.append("\n[").append(n++).append("] ").append(explicarProblemaDeSpec(p, spec));
        }
        return sb.append(LINHA).toString();
    }

    static String explicarProblemaDeSpec(String p, LocalizadorJson spec) {
        Matcher m;

        // Nome fora do padrão permitido (ex.: securitySchemes com espaço)
        m = Pattern.compile("^(.+?)\\.\\w+ name (.+) doesn't adhere to regular expression .+$").matcher(p);
        if (m.matches()) {
            List<String> caminho = segmentos(m.group(1));
            String nome = m.group(2);
            caminho.add(nome);
            LocalizadorJson.Chave def = spec == null ? null : spec.buscar(caminho);
            StringBuilder sb = new StringBuilder("Nome com caracteres não permitidos: \"" + nome + "\"\n");
            sb.append(campo("Local", exibir(caminho)));
            if (def != null) {
                sb.append(campo("Linha", String.valueOf(def.linha())));
            }
            if (spec != null) {
                List<Integer> refs = spec.linhasCom("\"" + nome + "\"");
                if (def != null) {
                    refs.remove(Integer.valueOf(def.linha()));
                }
                if (!refs.isEmpty()) {
                    sb.append(campo("Referências", (refs.size() == 1 ? "linha " : "linhas ") + juntar(refs)));
                }
            }
            sb.append(campo("Regra", "nomes de componentes aceitam apenas letras, números, \".\", \"-\" e \"_\"."));
            sb.append(campo("Correção", "renomear para \"" + nome.replaceAll("[^A-Za-z0-9.\\-_]", "")
                    + "\" na definição e em todas as referências."));
            return sb.toString();
        }

        // Parâmetro sem tipo definido
        m = Pattern.compile("^(.*parameters\\.([^.\\[\\]]+))\\.\\[[^\\]]*\\]\\.content is missing$").matcher(p);
        if (m.matches()) {
            List<String> caminho = segmentos(m.group(1));
            LocalizadorJson.Chave def = spec == null ? null : spec.buscar(caminho);
            StringBuilder sb = new StringBuilder("Parâmetro sem tipo definido: \"" + m.group(2) + "\"\n");
            sb.append(campo("Local", exibir(caminho)));
            if (def != null) {
                sb.append(campo("Linha", String.valueOf(def.linha())));
            }
            if (spec != null) {
                String ref = "#/" + String.join("/", caminho);
                int usos = spec.linhasCom("\"" + ref + "\"").size();
                if (usos > 0) {
                    sb.append(campo("Referências", usos + " operação(ões), via $ref \"" + ref + "\""));
                }
            }
            sb.append(campo("Regra", "todo parâmetro deve declarar \"schema\" (ou \"content\")."));
            sb.append(campo("Correção", "incluir \"schema\" com o tipo do valor, por exemplo {\"type\": \"integer\"}."));
            return sb.toString();
        }

        // Atributo não previsto no padrão (pode estar aninhado dentro do local informado)
        m = Pattern.compile("^attribute (.+)\\.([^.\\[\\]]+) is unexpected$").matcher(p);
        if (m.matches()) {
            List<String> local = segmentos(m.group(1));
            String atributo = m.group(2);
            List<LocalizadorJson.Chave> achados = new ArrayList<>();
            if (spec != null) {
                for (LocalizadorJson.Chave c : spec.chaves()) {
                    if (c.ultimo().equals(atributo) && c.dentroDe(local)) {
                        achados.add(c);
                    }
                }
            }
            StringBuilder sb = new StringBuilder("Atributo não permitido: \"" + atributo + "\"\n");
            if (achados.isEmpty()) {
                sb.append(campo("Local", exibir(local) + " (posição exata não identificada)"));
            } else {
                for (LocalizadorJson.Chave c : achados) {
                    sb.append(campo("Local", exibir(c.caminho().subList(0, c.caminho().size() - 1))));
                    sb.append(campo("Linha", c.linha() + "   " + spec.linha(c.linha())));
                }
            }
            sb.append(campo("Regra", "o atributo \"" + atributo + "\" não faz parte da especificação OpenAPI neste contexto."));
            sb.append(campo("Correção", "remover o atributo."));
            return sb.toString();
        }

        // Atributo obrigatório ausente
        m = Pattern.compile("^attribute (.+)\\.([^.\\[\\]]+) is missing$").matcher(p);
        if (m.matches()) {
            List<String> caminho = segmentos(m.group(1));
            LocalizadorJson.Chave def = spec == null ? null : spec.buscar(caminho);
            StringBuilder sb = new StringBuilder("Atributo obrigatório ausente: \"" + m.group(2) + "\"\n");
            sb.append(campo("Local", exibir(caminho)));
            if (def != null) {
                sb.append(campo("Linha", String.valueOf(def.linha())));
            }
            sb.append(campo("Correção", "incluir o atributo \"" + m.group(2) + "\"."));
            return sb.toString();
        }

        return "Problema não classificado\n" + campo("Detalhe técnico", p);
    }

    // =================================================================== resposta

    /** @param violacoes pares {chave da regra, mensagem técnica} */
    public static String respostaForaDoContrato(String arquivo, String metodo, String path, int status,
                                                List<String[]> violacoes) {
        // Agrupa a mesma divergência no mesmo campo (ignorando o índice da lista)
        Map<String, Grupo> grupos = new LinkedHashMap<>();
        for (String[] v : violacoes) {
            Violacao x = interpretar(v[0], v[1]);
            grupos.computeIfAbsent(x.chaveDeGrupo(), k -> new Grupo(x)).adicionar(x.indices());
        }

        StringBuilder sb = new StringBuilder(cabecalho("CONTRATO VIOLADO",
                metodo.toUpperCase() + " " + path + "  |  status " + status + "  |  " + arquivo));
        sb.append("A resposta difere do contrato documentado na spec.\n")
          .append(grupos.size()).append(grupos.size() == 1 ? " divergência" : " divergências")
          .append(" (").append(violacoes.size()).append(violacoes.size() == 1 ? " ocorrência).\n" : " ocorrências).\n");

        int n = 1;
        for (Grupo g : grupos.values()) {
            Violacao v = g.exemplo;
            sb.append("\n[").append(n++).append("] ").append(v.titulo()).append("\n");
            if (!v.campo().isEmpty()) {
                sb.append(campo("Campo", v.campo()));
            }
            if (g.ocorrencias > 1 || !g.indices.isEmpty()) {
                sb.append(campo("Ocorrências", g.ocorrencias + descreverIndices(g.indices)));
            }
            if (v.esperado() != null) {
                sb.append(campo("Esperado", v.esperado()));
                sb.append(campo("Recebido", v.recebido()));
            }
            if (v.observacao() != null) {
                sb.append(campo("Observação", v.observacao()));
            }
            sb.append(campo("Regra", v.regra()));
            sb.append(campo("Detalhe técnico", v.detalhe()));
        }
        return sb.append(LINHA).toString();
    }

    record Violacao(String regra, String titulo, String campo, List<Integer> indices,
                    String esperado, String recebido, String observacao, String detalhe) {
        String chaveDeGrupo() {
            return regra + "|" + campo + "|" + titulo;
        }
    }

    private static final class Grupo {
        final Violacao exemplo;
        final List<Integer> indices = new ArrayList<>();
        int ocorrencias;

        Grupo(Violacao exemplo) {
            this.exemplo = exemplo;
        }

        void adicionar(List<Integer> idx) {
            ocorrencias++;
            if (!idx.isEmpty()) {
                indices.add(idx.get(0));
            }
        }
    }

    static Violacao interpretar(String chave, String mensagem) {
        String k = chave == null ? "" : chave;
        String detalhe = mensagem == null ? "" : mensagem.trim();
        String ponteiro = null;
        Matcher m = Pattern.compile("^\\[Path '([^']*)'\\]\\s*(.*)$", Pattern.DOTALL).matcher(detalhe);
        if (m.matches()) {
            ponteiro = m.group(1);
            detalhe = m.group(2).trim();
        }
        List<Integer> indices = new ArrayList<>();
        String campo = ponteiro == null ? "" : campoAgrupado(ponteiro, indices);

        String titulo;
        String esperado = null;
        String recebido = null;
        String observacao = null;

        if (k.endsWith(".schema.type")) {
            Matcher t = Pattern.compile("Instance type \\((\\w+)\\).*allowed: \\[([^\\]]*)\\]").matcher(detalhe);
            if (t.find()) {
                recebido = t.group(1);
                esperado = t.group(2).replace("\"", "").replace(",", ", ");
            }
            if ("null".equals(recebido)) {
                titulo = "Valor nulo em campo não anulável";
                observacao = "a spec não declara o campo como anulável (nullable: true), mas a API retorna null.";
            } else {
                titulo = "Tipo de valor divergente";
            }
        } else if (k.endsWith(".schema.required")) {
            titulo = "Campo obrigatório ausente" + nomes(detalhe);
        } else if (k.endsWith(".schema.additionalProperties")) {
            titulo = "Campo não documentado na resposta" + nomes(detalhe);
        } else if (k.endsWith(".schema.enum")) {
            titulo = "Valor fora da lista de valores permitidos";
        } else if (k.endsWith(".schema.format")) {
            titulo = "Formato de valor divergente";
        } else if (k.contains(".schema.max") || k.contains(".schema.min")) {
            titulo = "Valor ou tamanho fora dos limites documentados";
        } else if (k.endsWith(".schema.pattern")) {
            titulo = "Valor fora do padrão documentado";
        } else if (k.endsWith("status.unknown")) {
            titulo = "Status HTTP não documentado para a operação";
        } else if (k.endsWith("path.missing")) {
            titulo = "Endpoint não documentado na spec";
        } else if (k.endsWith("operation.notAllowed")) {
            titulo = "Método HTTP não documentado para o endpoint";
        } else if (k.endsWith("body.missing")) {
            titulo = "Corpo da resposta ausente";
        } else if (k.contains("contentType")) {
            titulo = "Content-Type não documentado";
        } else {
            titulo = "Divergência de contrato";
        }
        return new Violacao(k, titulo, campo, indices, esperado, recebido, observacao, detalhe);
    }

    /** "/retorno/3/log_data" -> "retorno[*].log_data", guardando o índice 3 em "indices" */
    static String campoAgrupado(String ponteiro, List<Integer> indices) {
        if (ponteiro.isEmpty() || ponteiro.equals("/")) {
            return "(raiz da resposta)";
        }
        StringBuilder sb = new StringBuilder();
        for (String parte : ponteiro.substring(1).split("/")) {
            parte = parte.replace("~1", "/").replace("~0", "~");
            if (parte.matches("\\d+")) {
                indices.add(Integer.parseInt(parte));
                sb.append("[*]");
            } else {
                if (sb.length() > 0) {
                    sb.append(".");
                }
                sb.append(parte);
            }
        }
        return sb.toString();
    }

    /** [0,1,2,3] -> " (itens 0 a 3)"; [0,4,9] -> " (itens 0, 4, 9)" */
    static String descreverIndices(List<Integer> indices) {
        if (indices.isEmpty()) {
            return "";
        }
        List<Integer> ord = new ArrayList<>(indices);
        ord.sort(null);
        boolean sequencia = ord.get(ord.size() - 1) - ord.get(0) == ord.size() - 1;
        if (ord.size() == 1) {
            return " (item " + ord.get(0) + ")";
        }
        if (sequencia) {
            return " (itens " + ord.get(0) + " a " + ord.get(ord.size() - 1) + ")";
        }
        List<Integer> mostrar = ord.size() > 10 ? ord.subList(0, 10) : ord;
        return " (itens " + juntar(mostrar) + (ord.size() > 10 ? ", ..." : "") + ")";
    }

    // =================================================================== utilitários

    private static String cabecalho(String titulo, String subtitulo) {
        return LINHA + "\n" + titulo + "\n" + subtitulo + "\n" + LINHA + "\n";
    }

    /** Linha no formato "    Rótulo:          valor", com alinhamento fixo. */
    private static String campo(String rotulo, String valor) {
        return String.format("    %-17s%s%n", rotulo + ":", valor);
    }

    /** "attribute components.parameters.page.[page]" -> [components, parameters, page] */
    static List<String> segmentos(String caminho) {
        String limpo = caminho.replaceFirst("^attribute ", "").replaceAll("\\.\\[[^\\]]*\\]", "");
        return new ArrayList<>(List.of(limpo.split("\\.")));
    }

    static String exibir(List<String> caminho) {
        return String.join(" > ", caminho);
    }

    private static String nomes(String detalhe) {
        Matcher m = Pattern.compile("\\[(\"[^\\]]*\")\\]").matcher(detalhe);
        return m.find() ? ": " + m.group(1).replace("\"", "").replace(",", ", ") : "";
    }

    private static String juntar(List<Integer> numeros) {
        List<String> s = new ArrayList<>();
        for (Integer i : numeros) {
            s.add(String.valueOf(i));
        }
        return String.join(", ", s);
    }
}
