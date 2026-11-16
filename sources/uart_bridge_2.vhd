----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/05/2025 05:26:59 PM
-- Design Name: 
-- Module Name: uart_bridge_2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_bridge2 is
    Generic (
        CLK_FREQ    : integer := 100_000_000; 
        BAUD_RATE   : integer := 115_200      
    );
    Port ( 
        HORLOGE     : in  STD_LOGIC;
        RESET       : in  STD_LOGIC;
        
        -- Interface Terminal (PC via USB)
        tx_terminal : out STD_LOGIC;
        rx_terminal : in  STD_LOGIC;
        
        -- Interface ESP32 (Pmod ou fils volants)
        tx_esp32    : out STD_LOGIC;
        rx_esp32    : in  STD_LOGIC
    );
end uart_bridge2;

architecture Behavioral of uart_bridge2 is

    -- =========================================================================
    -- SIGNAUX INTERNES - SENS 1 : TERMINAL VERS ESP32
    -- =========================================================================
    -- Données sortant du RX (Terminal) -> entrant dans la FIFO
    signal rx_data_term      : std_logic_vector(7 downto 0);
    signal rx_valid_term     : std_logic; -- 'dat_en'

    -- Données sortant de la FIFO -> entrant dans le TX (ESP32)
    signal fifo_data_to_esp  : std_logic_vector(7 downto 0);
    signal fifo_empty_to_esp : std_logic;
    signal fifo_read_to_esp  : std_logic; -- Sert aussi de Start TX

    -- État du transmetteur ESP32
    signal tx_busy_esp       : std_logic;


    -- =========================================================================
    -- SIGNAUX INTERNES - SENS 2 : ESP32 VERS TERMINAL
    -- =========================================================================
    -- Données sortant du RX (ESP32) -> entrant dans la FIFO
    signal rx_data_esp       : std_logic_vector(7 downto 0);
    signal rx_valid_esp      : std_logic;

    -- Données sortant de la FIFO -> entrant dans le TX (Terminal)
    signal fifo_data_to_term : std_logic_vector(7 downto 0);
    signal fifo_empty_to_term: std_logic;
    signal fifo_read_to_term : std_logic;

    -- État du transmetteur Terminal
    signal tx_busy_term      : std_logic;


  
begin

    ----------------------------------------------------------------------------
    -- CHAÎNE 1 : TERMINAL (PC) --> FPGA --> ESP32
    ----------------------------------------------------------------------------

    -- 1. Réception (Depuis le PC)
    inst_rx_term : entity work.UART_recv
    port map (
        clk    => HORLOGE,
        reset  => RESET,
        rx     => rx_terminal,
        dat    => rx_data_term,
        dat_en => rx_valid_term  
    );

    -- 2. Buffer FIFO (Stockage temporaire)
    inst_fifo_term_to_esp : entity work.fifo
    port map (
        horloge   => HORLOGE,
        reset => RESET,
        -- Écriture (RX)
        wr_en => rx_valid_term,
        din   => rx_data_term,
        full  => open,
        -- Lecture (TX)
        rd_en => fifo_read_to_esp,
        dout  => fifo_data_to_esp,
        empty => fifo_empty_to_esp
    );

    -- 3. Contrôleur de flux
    process(HORLOGE)
    begin
        if rising_edge(HORLOGE) then
            if RESET = '1' then
                fifo_read_to_esp <= '0';
            else

                if (fifo_empty_to_esp = '0' and tx_busy_esp = '0') then
                    fifo_read_to_esp <= '1';
                else
                    fifo_read_to_esp <= '0';
                end if;
            end if;
        end if;
    end process;

    -- 4. Émission (Vers ESP32)
    inst_tx_esp : entity work.transmetteur
    port map (
        horloge  => HORLOGE,
        reset    => RESET,
        data_in  => fifo_data_to_esp,
        tx_start => fifo_read_to_esp, 
        tx       => tx_esp32,
        busy     => tx_busy_esp
    );


    ----------------------------------------------------------------------------
    -- CHAÎNE 2 : ESP32 --> FPGA --> TERMINAL (PC)
    ----------------------------------------------------------------------------

    -- 1. Réception (Depuis ESP32)
    inst_rx_esp : entity work.UART_recv
    port map (
        clk    => HORLOGE,
        reset  => RESET,
        rx     => rx_esp32,
        dat    => rx_data_esp,
        dat_en => rx_valid_esp
    );

    -- 2. Buffer FIFO
    inst_fifo_esp_to_term : entity work.fifo
    port map (
        horloge   => HORLOGE,
        reset => RESET,
        wr_en => rx_valid_esp,
        din   => rx_data_esp,
        full  => open,
        rd_en => fifo_read_to_term,
        dout  => fifo_data_to_term,
        empty => fifo_empty_to_term
    );

    -- 3. Contrôleur de flux
    process(HORLOGE)
    begin
        if rising_edge(HORLOGE) then
            if RESET = '1' then
                fifo_read_to_term <= '0';
            else
                if (fifo_empty_to_term = '0' and tx_busy_term = '0') then
                    fifo_read_to_term <= '1';
                else
                    fifo_read_to_term <= '0';
                end if;
            end if;
        end if;
    end process;

    -- 4. Émission (Vers PC)
    inst_tx_term : entity work.transmetteur
    port map (
        horloge  => HORLOGE,
        reset    => RESET,
        data_in  => fifo_data_to_term,
        tx_start => fifo_read_to_term,
        tx       => tx_terminal,
        busy     => tx_busy_term
    );

end Behavioral;
