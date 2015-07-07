COPY		= cp
DEL     = rm -f
ECHO		= echo

all:
	$(ECHO) "We have here 'install' and 'uninstall'."

uninstall:
	$(DEL) ~/AppData/Roaming/SketchUp/SketchUp 2015/SketchUp/Plugins/DComponentReporter.rb

install: uninstall
	$(COPY) DComponentReporter.rb "$(HOME)/AppData/Roaming/SketchUp/SketchUp 2015/SketchUp/Plugins/DComponentReporter.rb"
