----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.12.2025 21:42:44
-- Design Name: 
-- Module Name: consommateur - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity consommateur is
    Port ( 
        horloge     :   in std_logic;
        reset       :   in std_logic;
        
        tx_busy     :   in std_logic;
        fifo_empty  :   in std_logic;
        
        read_fifo   :   out std_logic;
        start_tx    :   out std_logic
    );
end consommateur;

architecture Behavioral of consommateur is
    type etat is (Attente, Lecture_FIFO, Attente_tx, Envoie, Transmission);
    
    signal etat_present : etat := Attente;
    signal etat_futur   : etat := Attente;
begin

    calcul_etat_futur: process(etat_present, fifo_empty, tx_busy)
    begin
        case etat_present is
            when Attente => 
                if fifo_empty = '0' then
                    etat_futur <= Lecture_FIFO;
                else
                    etat_futur <= Attente;
                end if;
                
            when Lecture_FIFO => 
                etat_futur <= Attente_tx;
                 
             when Attente_tx =>
                if tx_busy = '0' then
                    etat_futur <= Envoie;
                else
                    etat_futur <= Attente_tx;
                end if;
                             
            when Envoie =>
                    etat_futur <= Transmission;
                    
            when Transmission =>
                    if tx_busy = '1' then
                        etat_futur <= Attente;
                    else
                        etat_futur <= Transmission;
                    end if;
                 

        end case;
    end process;
    
    
    registre: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                etat_present <= Attente;
            else
                etat_present <= etat_futur;
            end if;
        end if;
    end process;
    
    calcul_sortie: process(etat_present)
    begin
        case etat_present is
            when Attente => read_fifo <= '0';
                            start_tx <= '0';
                            
            when Lecture_FIFO => read_fifo <= '1';
                                 start_tx <= '0';
                                 
            when Attente_tx => read_fifo <= '0';
                               start_tx <= '0';
                             
            when Envoie => read_fifo <= '0';
                           start_tx <= '1';
                           
            when Transmission => read_fifo <= '0';
                                 start_tx <= '0';
        end case;
    end process;


end Behavioral;
