----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/03/2025 02:33:44 PM
-- Design Name: 
-- Module Name: PWM - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PWM is
    Port (
        IDATA: in std_logic_vector (7 downto 0);
        HORLOGE: in std_logic;
        CE: in std_logic;
        RAZ: in std_logic;
        ODATA: out std_logic;
        VAL_REG_O: out std_logic_vector (7 downto 0)
        --AMP_SO: out std_logic
     );
end PWM;

architecture Behavioral of PWM is

    signal cpt: natural range 0 to 255;
    signal val: natural range 0 to 255;
    signal val_reg: natural range 0 to 255;
    
begin

    val <= TO_INTEGER(unsigned(IDATA));
    
    
   registre: process(HORLOGE)
    begin
        if rising_edge(HORLOGE) then
            if (RAZ = '1') then
                val_reg <= 0;
            elsif (CE = '1') then
                val_reg <= val;
            end if;
        end if;
     end process;
     
     
     compteur: process(HORLOGE)
     begin
        if rising_edge(HORLOGE) then
            if (RAZ = '1') then
                cpt <= 0;
            elsif (CE = '1') then
                cpt <= 0;
            else
                if (cpt=255) then
                cpt <= 0;
                else
                cpt <= cpt + 1;
                end if;
            end if;
       end if;
    end process;
    
    
    comparateur: process(val_reg, cpt)
    begin
        if (cpt < val_reg) then
            ODATA <= '1';
        else
            ODATA <= '0';
        end if;
    end process;
    
    
    VAL_REG_O <= std_logic_vector(to_unsigned(val_reg, 8));
    
    --AMP_SO <= '1';
    
end architecture;