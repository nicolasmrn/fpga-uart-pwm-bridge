----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/11/2025 09:36:37 PM
-- Design Name: 
-- Module Name: led_animation - Behavioral
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

entity led_animation is
    Generic (
        STEP_DELAY : integer := 200_000 
    );
    Port ( 
        horloge    : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        
        value_out  : out STD_LOGIC_VECTOR(7 downto 0);
        CE_pwm     : out std_logic 
    );
end led_animation;

architecture Behavioral of led_animation is

    signal counter_delay : integer range 0 to STEP_DELAY := 0;
    signal brightness    : integer range 0 to 255 := 0;
    signal direction     : std_logic := '1'; -- '1' = Monte, '0' = Descend

begin

    process(horloge)
    begin
        if rising_edge(horloge) then

            CE_pwm <= '0'; 

            if reset = '1' then
                brightness    <= 0;
                counter_delay <= 0;
                direction     <= '1';

            else

                if counter_delay < STEP_DELAY then
                    counter_delay <= counter_delay + 1;
                else
                    counter_delay <= 0; 

                    CE_pwm <= '1'; 

                    if direction = '1' then 
                        if brightness < 255 then
                            brightness <= brightness + 1;
                        else
                            direction <= '0'; 
                        end if;
                    else 
                        if brightness > 0 then
                            brightness <= brightness - 1;
                        else
                            direction <= '1'; 
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    value_out <= std_logic_vector(to_unsigned(brightness, 8));

end Behavioral;