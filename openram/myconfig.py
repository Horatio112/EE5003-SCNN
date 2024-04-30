word_size = 2

num_words = 16

num_r_ports = 1

num_w_ports = 1

tech_name = "sky130"

process_corners = [ "TT" ]

supply_voltages = [ 1.8 ]

temperatures = [ 25 ]

num_spare_rows = 1

num_spare_cols = 1

output_path = "output"

output_name = "sram_{0}_{1}_{2}".format(word_size,num_words,tech_name)
