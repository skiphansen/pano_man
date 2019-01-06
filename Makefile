CLEAN_LOG=-Dsbt.log.noformat=true 

sim:
	sbt $(CLEAN_LOG) "test-only rt.PanoTester"

syn:
	sbt $(CLEAN_LOG) "run-main panoman.PanomanTop"

waves:
	gtkwave -o simWorkspace/PanoCoreDut/test.vcd &
    
