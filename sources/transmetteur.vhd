----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/27/2025 02:14:59 PM
-- Design Name: 
-- Module Name: transmetteur - Behavioral
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity transmetteur is
    generic(
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 115_200
    );
    port(
        horloge     : in  std_logic;
        reset       : in  std_logic;
        data_in     : in  std_logic_vector(7 downto 0);
        tx_start    : in  std_logic;
        tx          : out std_logic;
        busy        : out std_logic
    );
end transmetteur;

 architecture Behavioral of transmetteur is

    constant BAUD_TICKS : integer := CLK_FREQ / BAUD_RATE;

    type etat_type is (IDLE, START, DATA, STOP);
    signal etat_present : etat_type := IDLE;
    signal etat_futur   : etat_type := IDLE;

    signal baud_cnt : integer := 0;
    signal bit_cnt  : integer := 0;
    signal shiftreg : std_logic_vector(7 downto 0) := (others => '0');

begin


    calcul_etat_future: process(etat_present, tx_start, baud_cnt, bit_cnt)
    begin
        case etat_present is
        
            when IDLE =>
                if tx_start = '1' then
                    etat_futur <= START;
                else
                    etat_futur <= IDLE;
                end if;

            when START =>
                if baud_cnt = BAUD_TICKS then
                    etat_futur <= DATA;
                else
                    etat_futur <= START;
                end if;

            when DATA =>
                if baud_cnt = BAUD_TICKS then
                    if bit_cnt = 7 then
                        etat_futur <= STOP;
                    else
                        etat_futur <= DATA;
                    end if;
                else
                    etat_futur <= DATA;
                end if;

            when STOP =>
                if baud_cnt = BAUD_TICKS then
                    etat_futur <= IDLE;
                else
                    etat_futur <= STOP;
                end if;
        end case;
    end process;


    registre: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                etat_present <= IDLE;
            else
                etat_present <= etat_futur;
            end if;
        end if;
    end process;


    process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                shiftreg <= (others => '0');

            elsif etat_present = IDLE and tx_start = '1' then
                shiftreg <= data_in;  -- CHARGEMENT

            elsif etat_present = DATA and baud_cnt = BAUD_TICKS then
                shiftreg <= '0' & shiftreg(7 downto 1);  -- DÉCALAGE
            end if;
        end if;
    end process;


    calcul_sortie: process(etat_present, shiftreg)
    begin
        case etat_present is
            when IDLE  =>
                tx   <= '1';
                busy <= '0';

            when START =>
                tx   <= '0';
                busy <= '1';

            when DATA  =>
                tx   <= shiftreg(0);
                busy <= '1';

            when STOP  =>
                tx   <= '1';
                busy <= '1';
        end case;
    end process;


    baud_counter: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                baud_cnt <= 1;

            elsif etat_present = IDLE then
                baud_cnt <= 1;

            elsif baud_cnt = BAUD_TICKS then
                baud_cnt <= 1;

            else
                baud_cnt <= baud_cnt + 1;
            end if;
        end if;
    end process;


    bit_counter: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                bit_cnt <= 0;

            elsif etat_present = DATA and baud_cnt = BAUD_TICKS then
                if bit_cnt = 7 then
                    bit_cnt <= 0;
                else
                    bit_cnt <= bit_cnt + 1;
                end if;
            end if;
        end if;
    end process;

end Behavioral;

