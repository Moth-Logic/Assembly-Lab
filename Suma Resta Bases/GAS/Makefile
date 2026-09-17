SRC = suma_resta_bases.s
OBJ = suma_resta_bases.o
BIN = suma_resta_bases

all: $(BIN)

$(OBJ): $(SRC)
	as -o $(OBJ) $(SRC)

$(BIN): $(OBJ)
	ld -o $(BIN) $(OBJ)

clean:
	rm -f $(OBJ) $(BIN)

.PHONY: all clean