----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 17.12.2025 22:09:44
-- Design Name: 
-- Module Name: tb_sender - Behavioral
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

entity tb_sender is
    -- L'entité du testbench est toujours vide
end tb_sender;

architecture Behavioral of tb_sender is

    -- 1. Déclaration du composant à tester (DUT : Design Under Test)
    component sender_instructions
        Port ( 
        HORLOGE :    in std_logic; 
        RESET   :    in std_logic;
        
        
        sig_ok      : in std_logic;
        sig_erreur  : in std_logic;
        sig_CNX     : in std_logic;
        sig_cmd     : in std_logic;
        
        
        tx_terminal : out std_logic;
        tx_esp32    : out std_logic
        );
    end component;

    -- 2. Signaux internes pour connecter au DUT
    signal tb_HORLOGE     : std_logic := '0';
    signal tb_RESET       : std_logic := '0';
    signal tb_ok      : std_logic := '0';
    signal tb_erreur      : std_logic := '0';
    signal tb_CNX      : std_logic := '0';
    signal tb_cmd      : std_logic := '0';
    
    
    -- Sorties à observer
    signal tb_tx_terminal : std_logic;
    signal tb_tx_esp32    : std_logic;

    -- 3. Constante pour la fréquence d'horloge (100 MHz = 10 ns)
    constant CLK_PERIOD : time := 10 ns;

begin

    -- 4. Instanciation de l'unité (Unit Under Test)
    uut: sender_instructions
    port map (
        HORLOGE     => tb_HORLOGE,
        RESET       => tb_RESET,
        sig_ok      => tb_ok,
        sig_erreur  => tb_erreur,
        sig_CNX     => tb_CNX,
        sig_cmd     => tb_cmd,
        tx_terminal => tb_tx_terminal,
        tx_esp32    => tb_tx_esp32
    );

    -- 5. Processus de génération d'horloge
    clk_process : process
    begin
        tb_HORLOGE <= '0';
        wait for CLK_PERIOD/2;
        tb_HORLOGE <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- 6. Processus de Stimulus (Scénario de test)
    stim_proc: process
    begin		
        -- Initialisation
        tb_RESET <= '1';   -- Reset actif
        tb_ok <= '0';
        tb_erreur <= '0';
        tb_CNX <= '0';
        tb_cmd <= '0';

        wait for 100 ns;

        -- Relâchement du Reset
        tb_RESET <= '0';
        wait for 100 ns;

        -- --- TEST 1 : Envoi d'une instruction (Ex: 0xAB) ---
        tb_ok <= '1';  -- Impulsion d'activation
        wait for CLK_PERIOD; -- Durée d'un cycle d'horloge
        tb_ok <= '0';

        -- Attente pour laisser le temps à l'UART de transmettre
        -- Avec un baud rate de 115200, un bit dure ~8.6 µs.
        -- Un octet complet (10 bits avec start/stop) prend ~86 µs.
        wait for 200 us; 

        -- --- TEST 2 : Envoi rapide de deux instructions (Test de la FIFO) ---
        tb_ok <= '1';
        wait for CLK_PERIOD;
        tb_ok <= '0';
        
        wait for 200 us; 
        
        tb_ok <= '1';
        wait for CLK_PERIOD;
        tb_ok <= '0';
        
        wait for 200 us; 
        
        tb_ok <= '1';
        wait for CLK_PERIOD;
        tb_ok <= '0';
        
        wait for 200 us; 
        
        
        tb_ok <= '1';
        wait for CLK_PERIOD;
        tb_ok <= '0';
        
        wait for 200 us; 
        
        
        tb_ok <= '1';
        wait for CLK_PERIOD;
        tb_ok <= '0';
        
        

        -- Attente longue pour voir toute la transmission série
        -- Il faut assez de temps pour sortir les deux octets de la FIFO
        wait for 2 ms;
    end process;

end Behavioral;
