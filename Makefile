#
# These are the variables you need to edit when files are added / removed
#
# PROGRAM_SOURCE is the name of the .cpp file holding the main method (including the .cpp suffix)
# LIBRARY_NAME is the name of the library file (do in include any prefixes or suffixes here)
# LIBRARY_SOURCES are the names of the .cpp files that comprise the library (including the .cpp suffix)
# LIBRARY_TYPE is either static (for an archive) or dynamic (for a dll/shared object library)
# DELIVERY_FOLDER is the name of the folder the deliveries should be copied to
# INTERMEDIATE_FOLDER is the name of the folder to contain the build files (do not include the ending /).
#

PROGRAM_SOURCE := program.cpp
TEST_PROGRAM_SOURCE := test.cpp
LIBRARY_NAME := dbwrap
LIBRARY_SOURCES := DatabaseException.cpp Database.cpp Statement.cpp ParamBuffer.cpp Binary.cpp
TEST_LIBRARY_SOURCES := UTFail.cpp TestNullable.cpp TestBinary.cpp TestDatabaseException.cpp TestDatabase.cpp
LIBRARY_TYPE := dynamic
DELIVERY_FOLDER := bin
INTERMEDIATE_FOLDER := build
DYLD_LIBRARY_PATH = /usr/local/mysql/lib
export DYLD_LIBRARY_PATH

#
# OS specific suffixes, prefixes, and switches used by make
#
# FOR OS/X: CPP=.cpp, OBJ=.o, DYS=.dylib, DYP=lib, ARS=.a, ARP=lib, EXE=<blank>, DEP=.d, USE_RPATH=yes, USE_INSTALLDIR=yes
# FOR WIN: CPP=.cpp, OBJ=.obj DYS=.dll, DYP=<blank>, ARS=.a, ARP=<blank>, EXE=.exe, DEP=.d, USE_RPATH=no, USE_INSTALLDIR=no
# FOR Linux: CPP=.cpp, OBJ=.o, DYS=.so, DYP=lib, ARS=.a, ARP=lib, EXE=<blank>, DEP=.d, USE_RPATH=yes, USE_INSTALLDIR=no
# Note - Linux is untested at this time
#

CPP := .cpp
OBJ := .o
DYS := .dylib
DYP := lib
ARS := .a
ARP := lib
EXE := 
DEP := .d
USE_RPATH := yes
USE_INSTALLDIR := yes

#
# Variables used internally by make
#

ifeq ($(INTERMEDIATE_FOLDER),)
	INTERMEDIATE_FOLDER := .
endif

INTERMEDIATE_FOLDER := $(addsuffix /,$(INTERMEDIATE_FOLDER))

PROGRAM_OBJECT := $(addprefix $(INTERMEDIATE_FOLDER),$(PROGRAM_SOURCE:$(CPP)=$(OBJ)))
TEST_PROGRAM_OBJECT := $(addprefix $(INTERMEDIATE_FOLDER),$(TEST_PROGRAM_SOURCE:$(CPP)=$(OBJ)))
PROGRAM_BINARY := $(PROGRAM_OBJECT:$(OBJ)=$(EXE))
TEST_PROGRAM_BINARY := $(TEST_PROGRAM_OBJECT:$(OBJ)=$(EXE))
LIBRARY_OBJECTS := $(addprefix $(INTERMEDIATE_FOLDER),$(LIBRARY_SOURCES:$(CPP)=$(OBJ)))
TEST_LIBRARY_OBJECTS := $(addprefix $(INTERMEDIATE_FOLDER),$(TEST_LIBRARY_SOURCES:$(CPP)=$(OBJ)))

ifeq ($(LIBRARY_NAME),)
	LIBRARY_TYPE :=
endif

ifeq ($(LIBRARY_TYPE),static)
	LIBRARY_FILE := $(addprefix $(INTERMEDIATE_FOLDER),$(ARP)$(LIBRARY_NAME)$(ARS))
	ARCHIVE_DEPEND := $(LIBRARY_FILE:$(ARS)=$(DEP)) 
	INSTALLIR :=
	LIBRARY_SWITCH := -l$(LIBRARY_NAME)
else 
	ifeq ($(LIBRARY_TYPE),dynamic)
		LIBRARY_FILE := $(addprefix $(INTERMEDIATE_FOLDER),$(DYP)$(LIBRARY_NAME)$(DYS))
		ARCHIVE_DEPEND := $(LIBRARY_FILE:$(DYS)=$(DEP)) 
		ifeq ($(USE_INSTALLDIR),yes)
			INSTALLDIR := -install_name @rpath/$(DYP)$(LIBRARY_NAME)$(DYS)
		else
			INSTALLDIR :=
		endif
		LIBRARY_SWITCH := -l$(LIBRARY_NAME)
	else
		LIBRARY_FILE ;=
		ACHIVE_DEPEND ;=
		INSTALLIR :=
		LIBRARY_SWITCH := $(LIBRARY_OBJECTS)
	endif
endif

PROGRAM_DEPEND := $(PROGRAM_OBJECT:$(OBJ)=$(DEP))
TEST_PROGRAM_DEPEND := $(TEST_PROGRAM_OBJECT:$(OBJ)=$(DEP))
LIBRARY_DEPEND := $(LIBRARY_OBJECTS:$(OBJ)=$(DEP))

CPP_INCDIR := ${shell /usr/local/mysql/bin/mysql_config --cflags}
CPP_LIBDIR := ${shell /usr/local/mysql/bin/mysql_config --libs}
#CPP_INCDIR := -I/usr/local/mysql/include
#CPP_LIBDIR := -L/usr/local/mysql/lib -lmysqlclient -lpthread
CPP_RPATH := -Wl,-rpath,/usr/local/mysql/lib

ifeq ($(LIBRARY_TYPE),dynamic)
	ifeq ($(USE_RPATH),yes)
		RPATH := -Wl,-rpath,. -Wl,-rpath,$(INTERMEDIATE_FOLDER) -Wl,-rpath,$(DELIVERY_FOLDER)
	else
		RPATH :=
	endif
endif

COVERAGE :=  -g -O0
COVERAGELIB := 

# end of variables - start of targets

.PHONY: all clean deliver cleanall run
.PRECIOUS: $(LIBRARY_OBJECTS)

all: $(PROGRAM_BINARY) $(TEST_PROGRAM_BINARY)

clean:
	rm -f $(PROGRAM_OBJECT) $(PROGRAM_BINARY) $(LIBRARY_OBJECTS) $(LIBRARY_FILE) $(TEST_PROGRAM_BINARY) $(TEST_PROGRAM_OBJECT) $(TEST_LIBRARY_OBJECTS)
	rm -f $(DELIVERY_FOLDER)/*


cleanall: clean
	rm -f $(INTERMEDIATE_FOLDER)*.d

deliver: all
	@mkdir -p $(DELIVERY_FOLDER)
	cp -f $(PROGRAM_BINARY) $(DELIVERY_FOLDER)
ifeq ($(LIBRARY_TYPE),dynamic)
	cp -f $(LIBRARY_FILE) $(DELIVERY_FOLDER)
endif

run: deliver
	@echo $(DYLD_LIBRARY_PATH)
	@for progs in $(PROGRAM_BINARY); do \
		$$progs; \
		echo "-----------------------------\n"; \
	done

runtest: $(TEST_PROGRAM_BINARY)
	@for progs in $(TEST_PROGRAM_BINARY); do \
		$$progs; \
	done
	
$(INTERMEDIATE_FOLDER)%$(OBJ): %$(CPP)
	g++ -Wall $(COVERAGE) -c $< $(CPP_INCDIR) -o $@
	@g++ -MM $< $(CPP_INCDIR) > $(@:$(OBJ)=$(DEP))
	@mv -f $(@:$(OBJ)=$(DEP)) $(@:$(OBJ)=$(DEP).tmp)
	@sed -e 's|.*:|$(@):|' < $(@:$(OBJ)=$(DEP).tmp) > $(@:$(OBJ)=$(DEP))
	@sed -e 's/.*://' -e 's/\\$$//' < $(@:$(OBJ)=$(DEP).tmp) | fmt -1 | \
  		sed -e 's/^ *//' -e 's/$$/:/' >> $(@:$(OBJ)=$(DEP))
	@rm -f $(@:$(OBJ)=$(DEP).tmp)

ifeq ($(LIBRARY_FILE),)
$(PROGRAM_BINARY): $(LIBRARY_OBJECTS)
endif

$(PROGRAM_BINARY): $(LIBRARY_FILE)

$(PROGRAM_BINARY): % : %$(OBJ)
	g++ -Wall $(<) $(CPP_INCDIR) $(LIBRARY_SWITCH) -o $(@) $(CPP_LIBDIR) -L$(INTERMEDIATE_FOLDER) $(RPATH) $(CPP_RPATH)
	@g++ -MM $(CPP_INCDIR) $(notdir $(<:$(OBJ)=$(CPP))) > $(<:$(OBJ)=$(DEP))
	@mv $(<:$(OBJ)=$(DEP)) $(<:$(OBJ)=.tmp)
	@sed "s|^.*:|$(@):|" $(<:$(OBJ)=.tmp) > $(<:$(OBJ)=$(DEP))
	@rm $(<:$(OBJ)=.tmp)

$(TEST_PROGRAM_BINARY): $(LIBRARY_FILE)

$(TEST_PROGRAM_BINARY): $(TEST_LIBRARY_OBJECTS)

$(TEST_PROGRAM_BINARY): % : %$(OBJ) 
	g++ -Wall $(COVERAGE)  $(<) $(LIBRARY_SWITCH) $(COVERAGELIB) $(TEST_LIBRARY_OBJECTS) -o $(@) $(CPP_LIBDIR) -L$(INTERMEDIATE_FOLDER) $(RPATH)
	@g++ -MM $(CPP_INCDIR) $(notdir $(<:$(OBJ)=$(CPP))) > $(<:$(OBJ)=$(DEP))
	@mv $(<:$(OBJ)=$(DEP)) $(<:$(OBJ)=.tmp)
	@sed "s|^.*:|$(@):|" $(<:$(OBJ)=.tmp) > $(<:$(OBJ)=$(DEP))
	@rm $(<:$(OBJ)=.tmp)

%$(ARS): $(LIBRARY_OBJECTS)
	ar -crs $(LIBRARY_FILE) $(LIBRARY_OBJECTS)
	@g++ -MM $(CPP_INCDIR) $(LIBRARY_SOURCES) > $(ARCHIVE_DEPEND)
	@mv $(ARCHIVE_DEPEND) $(ARCHIVE_DEPEND:$(DEP)=.tmp)
	@sed "s|^.*:|$(@):|" $(ARCHIVE_DEPEND:$(DEP)=.tmp) > $(ARCHIVE_DEPEND)
	@rm $(ARCHIVE_DEPEND:$(DEP)=.tmp)

%$(DYS): $(LIBRARY_OBJECTS)
	g++ -Wall $(COVERAGE) -shared $(CPP_INCDIR) $(LIBRARY_OBJECTS) $(COVERAGELIB) -o $(@) $(CPP_LIBDIR) $(INSTALLDIR)
	@g++ -MM $(CPP_INCDIR) $(LIBRARY_SOURCES) > $(ARCHIVE_DEPEND)
	@mv $(ARCHIVE_DEPEND) $(ARCHIVE_DEPEND:$(DEP)=.tmp)
	@sed "s|^.*:|$(@):|" $(ARCHIVE_DEPEND:$(DEP)=.tmp) > $(ARCHIVE_DEPEND)
	@rm $(ARCHIVE_DEPEND:$(DEP)=.tmp)


-include $(PROGRAM_DEPEND) $(ARCHIVE_DEPEND) $(LIBRARY_DEPEND) $(TEST_PROGRAM_DEPEND)

