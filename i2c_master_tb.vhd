library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Testbench для функціональної верифікації модуля I2C Master (Варіант 23)
entity i2c_master_tb is
end i2c_master_tb;

architecture Behavioral of i2c_master_tb is

    -- Компонент, що тестується (UUT - Unit Under Test)
    component i2c_master
        Generic (
            INPUT_CLK_FREQ : integer := 50_000_000;
            BUS_CLK_FREQ   : integer := 100_000
        );
        Port (
            clk       : in    STD_LOGIC;
            reset     : in    STD_LOGIC;
            ena       : in    STD_LOGIC;
            addr      : in    STD_LOGIC_VECTOR(6 downto 0);
            rw        : in    STD_LOGIC;
            data_wr   : in    STD_LOGIC_VECTOR(7 downto 0);
            busy      : out   STD_LOGIC;
            data_rd   : out   STD_LOGIC_VECTOR(7 downto 0);
            ack_error : out   STD_LOGIC;
            sda       : inout STD_LOGIC;
            scl       : inout STD_LOGIC
        );
    end component;

    -- Сигнали для підключення до UUT
    signal clk_sig       : STD_LOGIC := '0';
    signal reset_sig     : STD_LOGIC := '1';
    signal ena_sig       : STD_LOGIC := '0';
    signal addr_sig      : STD_LOGIC_VECTOR(6 downto 0) := (others => '0');
    signal rw_sig        : STD_LOGIC := '0';
    signal data_wr_sig   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal busy_sig      : STD_LOGIC;
    signal data_rd_sig   : STD_LOGIC_VECTOR(7 downto 0);
    signal ack_error_sig : STD_LOGIC;
    signal sda_sig       : STD_LOGIC;
    signal scl_sig       : STD_LOGIC;

    -- Сигнал керування лінією SDA з боку імітованого Slave-пристрою
    signal slave_sda_drv : STD_LOGIC := 'Z';

    constant CLK_PERIOD : time := 20 ns; -- Частота 50 МГц

begin

    -- Інстанціювання модуля I2C Master
    uut: i2c_master
        Generic map (
            INPUT_CLK_FREQ => 50_000_000,
            BUS_CLK_FREQ   => 100_000
        )
        Port map (
            clk       => clk_sig,
            reset     => reset_sig,
            ena       => ena_sig,
            addr      => addr_sig,
            rw        => rw_sig,
            data_wr   => data_wr_sig,
            busy      => busy_sig,
            data_rd   => data_rd_sig,
            ack_error => ack_error_sig,
            sda       => sda_sig,
            scl       => scl_sig
        );

    -- Імітація підтягуючих резисторів (Pull-up) шини I2C до високого рівня ('H')
    sda_sig <= 'H';
    scl_sig <= 'H';
    sda_sig <= slave_sda_drv;

    -- Генерація тактового сигналу 50 МГц
    clk_process: process
    begin
        clk_sig <= '0';
        wait for CLK_PERIOD / 2;
        clk_sig <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Процес імітації роботи зовнішнього Slave-пристрою (видача ACK та даних для Rx)
    slave_sim_process: process
        constant SLAVE_TX_BYTE : STD_LOGIC_VECTOR(7 downto 0) := "00111100"; -- 0x3C для читання
    begin
        slave_sda_drv <= 'Z';
        -- Чекаємо умову START (спад SDA при високому SCL)
        wait until falling_edge(sda_sig) and (scl_sig /= '0');

        -- Пропускаємо 8 тактів адреси + R/W
        for i in 0 to 7 loop
            wait until falling_edge(scl_sig);
        end loop;

        -- 9-й такт: Slave видає ACK ('0') на адресу
        slave_sda_drv <= '0';
        wait until falling_edge(scl_sig);
        slave_sda_drv <= 'Z';

        if rw_sig = '0' then
            -- Режим запису (Tx): пропускаємо 8 біт даних від Master
            for i in 0 to 7 loop
                wait until falling_edge(scl_sig);
            end loop;
            -- Видаємо ACK ('0') на прийнятий байт даних
            slave_sda_drv <= '0';
            wait until falling_edge(scl_sig);
            slave_sda_drv <= 'Z';
        else
            -- Режим читання (Rx): Slave побітово передає байт SLAVE_TX_BYTE на лінію SDA
            for i in 7 downto 0 loop
                slave_sda_drv <= SLAVE_TX_BYTE(i);
                wait until falling_edge(scl_sig);
            end loop;
            slave_sda_drv <= 'Z';
        end if;
    end process;

    -- Головний процес подачі тестових впливів (Stimulus)
    stimulus_process: process
    begin
        -- Початкове скидання системи
        reset_sig <= '1';
        wait for 100 ns;
        reset_sig <= '0';
        wait for 200 ns;

        -- ТЕСТ 1: Запис (Write) байта 0xA5 (10100101) у Slave з адресою 0x52 (1010010)
        addr_sig    <= "1010010";
        rw_sig      <= '0';
        data_wr_sig <= "10100101";
        ena_sig     <= '1';
        wait for 20 us;
        ena_sig     <= '0';

        -- Очікуємо завершення транзакції запису
        wait until busy_sig = '0';
        wait for 50 us;

        -- ТЕСТ 2: Читання (Read) байта від Slave з адресою 0x52 (очікуємо отримати 0x3C)
        addr_sig    <= "1010010";
        rw_sig      <= '1';
        ena_sig     <= '1';
        wait for 20 us;
        ena_sig     <= '0';

        -- Очікуємо завершення транзакції читання
        wait until busy_sig = '0';
        wait for 50 us;

        -- Завершення симуляції
        assert false report "Simulation Finished Successfully!" severity failure;
        wait;
    end process;

end Behavioral;