package rhnet.support.dados;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Massa de dados sintética e thread-safe (os testes rodam em paralelo).
 * Todo dado criado leva o prefixo "QA AUTO", o que facilita identificá-lo e limpá-lo.
 *
 * Uso no Karate:
 *   * def Dados = Java.type('rhnet.support.dados.GeradorDados')
 *   * def cpf = Dados.cpf()
 */
public final class GeradorDados {

    public static final String PREFIXO = "QA AUTO";

    private static final String[] NOMES = {"Ana", "Bruno", "Carla", "Diego", "Elisa", "Fabio", "Gabriela", "Heitor"};
    private static final String[] SOBRENOMES = {"Silva", "Souza", "Oliveira", "Pereira", "Costa", "Rodrigues", "Almeida"};
    private static final DateTimeFormatter DATA_HORA = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private GeradorDados() {
    }

    /** CPF válido (dígitos verificadores corretos), sem máscara. */
    public static String cpf() {
        ThreadLocalRandom r = ThreadLocalRandom.current();
        int[] d = new int[11];
        do {
            for (int i = 0; i < 9; i++) {
                d[i] = r.nextInt(10);
            }
        } while (todosIguais(d));
        d[9] = digitoVerificador(d, 9);
        d[10] = digitoVerificador(d, 10);
        StringBuilder sb = new StringBuilder();
        for (int x : d) {
            sb.append(x);
        }
        return sb.toString();
    }

    public static boolean cpfValido(String cpf) {
        if (cpf == null || !cpf.matches("\\d{11}")) {
            return false;
        }
        int[] d = cpf.chars().map(c -> c - '0').toArray();
        return !todosIguais(d) && d[9] == digitoVerificador(d, 9) && d[10] == digitoVerificador(d, 10);
    }

    public static String nome() {
        ThreadLocalRandom r = ThreadLocalRandom.current();
        return PREFIXO + " " + NOMES[r.nextInt(NOMES.length)] + " " + SOBRENOMES[r.nextInt(SOBRENOMES.length)];
    }

    /** Sufixo curto e único, para evitar colisão entre testes paralelos. */
    public static String sufixo() {
        return Long.toString(System.nanoTime(), 36).toUpperCase();
    }

    public static String hoje() {
        return LocalDate.now().toString();
    }

    public static String diasAPartirDeHoje(int dias) {
        return LocalDate.now().plusDays(dias).toString();
    }

    public static String agora() {
        return LocalDateTime.now().format(DATA_HORA);
    }

    private static int digitoVerificador(int[] d, int tamanho) {
        int soma = 0;
        for (int i = 0; i < tamanho; i++) {
            soma += d[i] * (tamanho + 1 - i);
        }
        int resto = soma % 11;
        return resto < 2 ? 0 : 11 - resto;
    }

    private static boolean todosIguais(int[] d) {
        for (int i = 1; i < 9; i++) {
            if (d[i] != d[0]) {
                return false;
            }
        }
        return true;
    }
}
