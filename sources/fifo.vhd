----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/05/2025 05:19:53 PM
-- Design Name: 
-- Module Name: fifo - Behavioral
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo is
    Generic (
        DATA_WIDTH : integer := 8;
        FIFO_DEPTH : integer := 64
    );
    Port ( 
        horloge  : in  STD_LOGIC;
        reset    : in  STD_LOGIC; 
        
        wr_en    : in  STD_LOGIC; 
        din      : in  STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
        full     : out STD_LOGIC;
        
        rd_en    : in  STD_LOGIC; 
        dout     : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
        empty    : out STD_LOGIC 
    );
end fifo;

architecture Behavioral of fifo is

    type memory_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal memory : memory_type; 
    
    signal wr_ptr  : natural range 0 to FIFO_DEPTH-1 := 0;
    signal rd_ptr  : natural range 0 to FIFO_DEPTH-1 := 0;
    signal nb_elem : natural range 0 to FIFO_DEPTH   := 0;
    

    signal full_i  : std_logic;
    signal empty_i : std_logic;
    
    

begin

    full  <= full_i;
    empty <= empty_i;

    full_combinatoire: process(nb_elem)
    begin
        if nb_elem = FIFO_DEPTH then
            full_i <= '1';
        else
            full_i <= '0';
        end if;
    end process;


    empty_combinatoire: process(nb_elem)
    begin
        if nb_elem = 0 then
            empty_i <= '1';
        else
            empty_i <= '0';
        end if;
    end process;



    ecriture: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                wr_ptr <= 0;
            else

                if wr_en = '1' and full_i = '0' then
                    memory(wr_ptr) <= din;
                    if wr_ptr = FIFO_DEPTH-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- 3. Process de lecture
    lecture: process(horloge)
    begin
        if rising_edge(horloge) then
            if reset = '1' then
                rd_ptr <= 0;
                dout   <= (others => '0');
            else

                if rd_en = '1' and empty_i = '0' then
                    dout <= memory(rd_ptr);
                    if rd_ptr = FIFO_DEPTH-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    comptage: process(horloge)

    begin
        if rising_edge(horloge) then
            if reset = '1' then
                nb_elem <= 0;
            else


                if (wr_en = '1' and full_i = '0') and (rd_en = '0' or empty_i = '1') then
                    nb_elem <= nb_elem + 1;
                elsif (rd_en = '1' and empty_i = '0') and (wr_en = '0' or full_i = '1') then
                    nb_elem <= nb_elem - 1;
                end if;

            end if;
        end if;
    end process;
    
end Behavioral;