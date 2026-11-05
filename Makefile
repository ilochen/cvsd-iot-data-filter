.PHONY: test
test:
	mkdir -p build
	verilator --binary --timing -Wno-fatal --top-module filter_tb --Mdir build rtl/IOTDF.v tests/filter_tb.sv
	@for suite in 1; do for fn in 1 2 3 4; do ./build/Vfilter_tb +suite=$$suite +fn=$$fn || exit 1; done; done
