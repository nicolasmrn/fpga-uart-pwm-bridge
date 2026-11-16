library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parser is
    Port (
        horloge     : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        rx_data     : in  STD_LOGIC_VECTOR(7 downto 0);
        rx_dv       : in  STD_LOGIC;
        
        -- Sorties
        sig_ok      : out STD_LOGIC;
        sig_erreur  : out STD_LOGIC;
        sig_CNX     : out STD_LOGIC;
        
        sig_cmd     : out STD_LOGIC;
        data_cmd    : out STD_LOGIC_VECTOR(23 downto 0)
    );
end parser;

architecture Behavioral of parser is

    -- Constantes ASCII
    constant CHAR_COLON : std_logic_vector(7 downto 0) := x"3A"; -- ':'
    constant CHAR_COMMA : std_logic_vector(7 downto 0) := x"2C"; -- ','
    constant CHAR_0     : std_logic_vector(7 downto 0) := x"30"; -- '0'
    constant CHAR_9     : std_logic_vector(7 downto 0) := x"39"; -- '9'

    -- Types
    type shift_reg_t is array (6 downto 0) of std_logic_vector(7 downto 0);
    type data_state_t is (IDLE, WAIT_COLON, PARSE_RED, PARSE_GREEN, PARSE_BLUE);

    -- Signaux d'état
    signal etat_present : data_state_t := IDLE;
    signal etat_futur    : data_state_t;

    -- Registres internes
    signal window      : shift_reg_t := (others => (others => '0'));
    signal cnx_reg     : std_logic := '0';
    
    signal acc         : unsigned(7 downto 0) := (others => '0');
    signal red_reg     : unsigned(7 downto 0) := (others => '0');
    signal green_reg   : unsigned(7 downto 0) := (others => '0');
    

    signal cmd_storage : std_logic_vector(23 downto 0) := (others => '0');

begin


    sig_CNX  <= cnx_reg;
    data_cmd <= cmd_storage; 

    proc_next_state: process(etat_present, rx_data, window, rx_dv)
    begin 
        if rx_dv = '1' then
            case etat_present is
                when IDLE =>
                    if rx_data = x"44" and window(0) = x"50" and window(1) = x"49" and window(2) = x"2B" then
                        etat_futur <= WAIT_COLON;
                    else
                         etat_futur <= etat_present; 
                    end if;
                when WAIT_COLON  => 
                    if rx_data = CHAR_COLON then 
                        etat_futur <= PARSE_RED;
                    else
                         etat_futur <= etat_present; 
                    end if;
                when PARSE_RED   => 
                    if rx_data = CHAR_COMMA then 
                        etat_futur <= PARSE_GREEN;
                    else
                         etat_futur <= etat_present; 
                    end if;
                when PARSE_GREEN => 
                    if rx_data = CHAR_COMMA then 
                        etat_futur <= PARSE_BLUE;
                    else
                         etat_futur <= etat_present;  
                    end if;
                when PARSE_BLUE  => 
                    if not (rx_data >= CHAR_0 and rx_data <= CHAR_9) then 
                        etat_futur <= IDLE; 
                    else
                         etat_futur <= etat_present; 
                    end if;
            end case;
        end if;
    end process proc_next_state;



    registre: process(horloge)
    begin
        if rising_edge(horloge) then

            if reset = '1' then
                etat_present <= IDLE;
                cnx_reg       <= '0';
                acc           <= (others => '0');
                red_reg       <= (others => '0');
                green_reg     <= (others => '0');
                window        <= (others => (others => '0'));
                cmd_storage   <= (others => '0'); 
            
            elsif rx_dv = '1' then
    
                etat_present <= etat_futur;
                
                window <= window(5 downto 0) & rx_data;

                if rx_data = x"54" and window(0) = x"43" and window(1) = x"45" then 
                    cnx_reg <= '1'; 
                end if;
                
                if rx_data = x"44" and window(0) = x"45" and window(1) = x"53" then 
                    cnx_reg <= '0'; 
                end if;


                case etat_present is
                    when WAIT_COLON =>
                        if rx_data = CHAR_COLON then acc <= (others => '0'); end if;

                    when PARSE_RED =>
                        if rx_data >= CHAR_0 and rx_data <= CHAR_9 then
                            acc <= resize((acc * 10) + (unsigned(rx_data) - unsigned(CHAR_0)), 8);
                        elsif rx_data = CHAR_COMMA then
                            red_reg <= acc;
                            acc     <= (others => '0');
                        end if;

                    when PARSE_GREEN =>
                        if rx_data >= CHAR_0 and rx_data <= CHAR_9 then
                            acc <= resize((acc * 10) + (unsigned(rx_data) - unsigned(CHAR_0)), 8);
                        elsif rx_data = CHAR_COMMA then
                            green_reg <= acc;
                            acc       <= (others => '0');
                        end if;

                    when PARSE_BLUE =>
                        if rx_data >= CHAR_0 and rx_data <= CHAR_9 then
                            acc <= resize((acc * 10) + (unsigned(rx_data) - unsigned(CHAR_0)), 8);
                        else

                            cmd_storage <= std_logic_vector(red_reg) & std_logic_vector(green_reg) & std_logic_vector(acc);
                        end if;
                        
                    when others => null;
                end case;
            end if;
        end if;
    end process;


    calcul_sortie: process(etat_present, rx_dv, rx_data, window)
    begin

        sig_ok     <= '0';
        sig_erreur <= '0';
        sig_cmd    <= '0'; 


        if rx_dv = '1' then
            if etat_present = IDLE then
                if rx_data = x"4B" and window(0) = x"4F" then sig_ok <= '1'; end if;
                if rx_data = x"79" and window(0) = x"64" then sig_ok <= '1'; end if; 
                if rx_data = x"52" and window(0) = x"4F" and window(1) = x"52" then sig_erreur <= '1'; end if;
            end if;

            if etat_present = PARSE_BLUE then

                if not (rx_data >= CHAR_0 and rx_data <= CHAR_9) then
                    sig_cmd <= '1';
                end if;
            end if;
        end if;
    end process;

end Behavioral;