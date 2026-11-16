----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.12.2025 21:02:04
-- Design Name: 
-- Module Name: multiplexeur_animation - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity multiplexeur_animation is
    Port (
        cmd : in std_logic_vector (1 downto 0);
        CE_fsm: in std_logic;
        led_breath  : in std_logic_vector (7 downto 0);
        CE_breath   : in std_logic;
        
        R_user : in std_logic_vector (7 downto 0);
        G_user : in std_logic_vector (7 downto 0);
        B_user : in std_logic_vector (7 downto 0);
        
        R : out std_logic_vector (7 downto 0);
        G : out std_logic_vector (7 downto 0);
        B : out std_logic_vector (7 downto 0);
        CE : out std_logic
     );
end multiplexeur_animation;

architecture Behavioral of multiplexeur_animation is

begin

    process(cmd)
    begin
        case cmd is 
            when "00" =>
                R <= std_logic_vector(to_unsigned(255, 8));
                G <= std_logic_vector(to_unsigned(0, 8));
                B <= std_logic_vector(to_unsigned(0, 8));
                CE <= CE_fsm;
            when "01" =>
                R <= led_breath;
                G <= led_breath;
                B <= led_breath;
                CE <= CE_breath;
            when "10" =>
                R <= std_logic_vector(to_unsigned(200, 8));
                G <= std_logic_vector(to_unsigned(20, 8));
                B <= std_logic_vector(to_unsigned(0, 8));
                CE <= CE_fsm;
                
            when "11" => 
                R <= R_user;
                G <= G_user;
                B <= B_user;
                CE <= CE_fsm;
                
                
            when others =>
                R <= led_breath;
                G <= led_breath;
                B <= led_breath;
                CE <= CE_breath;
                
                
         end case;
                
    end process;


end Behavioral;
