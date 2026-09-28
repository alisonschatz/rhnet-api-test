import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

/**
 * Define o nome do relatório Allure: "RH NET Social · Testes de API (<AMBIENTE>)".
 *
 * Necessário porque o plugin allure-maven fixa o nome do relatório como "Allure", e a interface
 * do Allure 3 ignora a opção reportName na geração do HTML. O nome aparece em dois pontos do
 * index.html: o <title> (aba do navegador) e as opções do relatório (cabeçalho da página).
 *
 * Se o formato do HTML mudar em uma versão futura do Allure, o programa apenas avisa e mantém
 * o relatório como está: nunca interrompe a execução.
 *
 * Uso: java scripts/NomeRelatorioAllure.java target/allure-report/index.html hml|prd
 */
public class NomeRelatorioAllure {

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Uso: java scripts/NomeRelatorioAllure.java <index.html> <ambiente>");
            return;
        }
        Path arquivo = Path.of(args[0]);
        if (!Files.exists(arquivo)) {
            System.err.println("Relatório Allure não encontrado: " + arquivo);
            return;
        }
        // "\u00b7" é o ponto médio (·), escrito assim para independer da codificação do sistema
        String nome = "RH NET Social \u00b7 Testes de API (" + args[1].toUpperCase(Locale.ROOT) + ")";

        String html = Files.readString(arquivo, StandardCharsets.UTF_8);
        if (html.contains("\"reportName\":\"" + nome + "\"")) {
            return; // já ajustado
        }
        String titulo = "<title> Allure </title>";
        String opcao = "\"reportName\":\"Allure\"";
        if (!html.contains(titulo) || !html.contains(opcao)) {
            System.err.println("Aviso: formato do relatório Allure não reconhecido; o nome não foi alterado.");
            return;
        }
        html = html.replace(titulo, "<title> " + nome + " </title>")
                   .replace(opcao, "\"reportName\":\"" + nome + "\"");
        Files.writeString(arquivo, html, StandardCharsets.UTF_8);
    }
}
