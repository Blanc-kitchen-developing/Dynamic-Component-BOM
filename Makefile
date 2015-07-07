COPY		= cp
DEL     = rm -f

uninstall:
	$(DEL) ~/AppData/Roaming/SketchUp/SketchUp 2015/SketchUp/Plugins/DComponentReporter.rb

install: uninstall
	$(COPY) DComponentReporter.rb ~/AppData/Roaming/SketchUp/SketchUp 2015/SketchUp/Plugins/DComponentReporter.rb
