PROTO_PATH=.

.PHONY : all clean

# PROTOS = CGGame Jinhua NiuNiu Tractor Landlord Guandan Battleship BlackJack Holdem \
		 Ludo Xiangqi Chess Gomoku CNChecker Mahjong13 Mahjong2 AnQing YunCheng \
		 Snake CellGame Rocket

PROTOS = CGGame YunCheng \
		 Rocket

all : $(foreach v, $(PROTOS), $(v).pb)

%pb:%proto
	@rm -f $@
	@echo "generate $@"
	@protoc -I$(PROTO_PATH) -o $(PROTO_PATH)/$@ $(PROTO_PATH)/$<

clean :
	@echo "clean all pb files"
	@rm -f *.pb
