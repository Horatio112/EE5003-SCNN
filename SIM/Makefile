all: com sim debug

com:
	vcs +v2k +notimingcheck +nospecify -full64 -fsdb -sverilog -debug_all -timescale=1ns/1ps -f file.list -l com.log

sim:
	./simv -l sim.log

debug:
	verdi -sv -f file.list -ssf tb.fsdb &
clean:
	rm -rf *.log ./csrc *.daidir  simv* *.key *.vpd DVEfiles coverage *.vdb *race.out* novas* verdi* *fsdb apb2apb_async sharedMem*
