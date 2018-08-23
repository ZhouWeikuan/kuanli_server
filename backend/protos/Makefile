PROTO_PATH=.

.PHONY : all clean

PROTOS = CGGame

all : $(foreach v, $(PROTOS), $(v).pb)

%pb:%proto
	@rm -f $@
	@echo "generate $@"
	@protoc -I$(PROTO_PATH) -o $(PROTO_PATH)/$@ $(PROTO_PATH)/$<

clean :
	@echo "clean all pb files"
	@rm -f *.pb
