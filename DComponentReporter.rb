#----------------------------------------------------------------------------#

## Copyright 2015-2015, tobiashochguertel.de
#
# @author Tobias, Hochguertel <tobias.hochguertel@googlemail.com>
#
## Copyright 2005-2008, Google, Inc.
# ShoreStation Dock Quote generator
# Modifiled on 4-13-2009 by Jon Devitt jon.devitt@gmail.com
# Original code provided by Scott Lininger at Sketchup

#----------------------------------------------------------------------------#

require 'sketchup.rb'

# Monkeypatching the hash to allow the uniq function of array to work...
	class Hash
		def hash
			to_a.hash
		end
		alias eql? ==
	end

# AttributeReporter class, provide useful reporting for the attributes attached to your
# Components and Groups
#
# Put this file in the Plugins directory and you should be good to go.
# You will have a right click to save attributes information for a selection and
# a menu under Plugins to save the whole Model attributes information.
class DCompReporter

  #Setup the file
  def set_up(filename)

    # Arrays
    @group_list = []
    @component_list = []

    # Dictionary where the DC attributes are stored.
    @dictionary_name = "dynamic_attributes"

    # Create some global structures to store our report data in as
    # it is built. Note that this is a RAM intensive approach, so extremely
    # large reports could run into memory problems.
    @report_data = []

    # This array will contain an ordered list of the attribute names we've
    # encountered as we walk the model.
    @report_attribute_list = []

	#Array of items with an itemcode attribute value.
	@item_list = []
	@notelist = []

    # Calculate the file type based on the characters after the last dot in the file name.
    @filetype = (filename.split('.').last).downcase
    @filename = filename

    # In an effort to allow for extending the report formats down the
    # road, the reporter uses a simple templating system that allows you to
    # define strings that start and end the report, the rows, and the cells.
    # you can easily add more formats here
    if @filetype == "csv"

      @doc_start  = ""
      @doc_end    = ""
      @row_start  = ""
      @row_end    = "\n"
      @cell_start = ""
      @cell_mid   = ","
      @cell_end   = ","
	  @totalrow = ",,,Total Price:"

      else # default to html
        @doc_start = "<html><head><meta http-equiv=\"Content-Type\" " +
        "content=\"text/html; charset=utf-8\"><title>Component List</title>" +
		"</head>\n" +
        "<style> table {\n" +
        "  padding: 0px;\n" +
        "  margin: 0px;\n" +
        "  empty-cells: show;\n" +
        "  border-right: 1px solid silver;\n" +
        "  border-bottom: 1px solid silver;\n" +
        "  border-collapse: collapse;\n" +
        "}\n" +
        "td {\n" +
        "  padding: 4px;\n" +
        "  margin: 0px;\n" +
        "  border-left: 1px solid silver;\n" +
        "  border-top: 1px solid silver;\n" +
        "  font-family: sans-serif;\n" +
        "  font-size: 9pt;\n" +
        "  vertical-align: top;\n" +
        "}\n</style>\n\n<hr>" +
        "<table border=1>"
		createtime=Time.new
        @table_end    = "</table>"
		@dock_end  = "</body><div></html>"
        @row_start  = "   <tr>\n"
        @row_end    = "   </tr>\n"
        @cell_start = "    <td>"
        @cell_mid   = "</td>\n    <td>"
        @cell_end   = "</td>\n"
		@totalrow = "<td colspan = 4 align = \"right\">" + "<b>Total Price:</b>&nbsp&nbsp"

    end
  end

  # This method returns a named attribute from the DC dictionary. It looks
  # on the instance first... if no attribute is found there, it looks on
  # the definition next.
  #
  #   Args:
  #      entity: reference to the entity to get the value from
  #      name: string name of the attribute to return the value for
  #
  #   Returns:
  #      the value of the attribute, or nil if it can't determine that
  def get_attribute_value(entity,name)
    name = name.downcase

    if entity.typename == 'ComponentInstance'
      value = entity.get_attribute @dictionary_name, name
      if value == nil
        value = entity.definition.get_attribute(@dictionary_name, name)
      end
      return value
    elsif entity.typename == 'Group' || entity.typename == "Model" ||
      entity.typename == 'ComponentDefinition'
      return entity.get_attribute(@dictionary_name, name)
    else
      return nil
    end
  end

  # This methods loops through all the model entities and process them in case they are
  # either Components or Groups. Here more functionality can be added in case we want
  # to report about different entities.
  #
  #   Args:
  #      list: beginning entities list used to communicate to this function
  #      whether or not we are processing all the model entities or just the current
  #      selection
  #
  #   Returns:
  #      None

  # Modified to call the create_item_list function to grab only the Item Number and Description attributes
  def collect_attributes(list)
    n = 0
    # Determine the number and types of entities.
    while list != []    # While there are still entities in the list array, determine their type and count them.
      list.each do |item|
      n +=1
      type = item.typename
      case type
        when "Group"
          item.entities.each do |entity|  # Add all the entities that are in that group into the group_list array.
          @group_list.push entity
        end
          #get the attributes and put them in the report string
          @group_list.delete(item)
          create_item_list(item, n)
        when "ComponentInstance"
        # You can call .entities on Component Definition, but not on Component Instance.
        # You need to figure out which ComponentDefinition the instance belongs to.  (ComponentDefinition=ComponentInstance.definition)
        item.definition.entities.each do |entity|
            @component_list.push entity  # Add all the entities that are in the component to the component_list array.
        end
        #get the attributes and put them in the report string
		create_item_list(item, n)
        #get rid of the item we have already examined in the list
        @component_list.delete(item)
      end
    end
    # Update the list array so it countains only the entities that were part of sub-groups and sub-arrays. Those sub-entities haven't been counted yet.
    list = @group_list + @component_list
    # Clear out the group and component lists so they're ready for the next level of sub-groups/components.
    @group_list.clear
    @component_list.clear
    end
  end

  #Function to get the itemcode and description attributes from the dynamic components. If no value is found for the itemcode, then
  #The item is ignored. If item code is found, it is added to the item_list array of hashes.
  def create_item_list(entity, number)
		item = get_attribute_value(entity,'itemcode')
		description = get_attribute_value(entity,'description')
		hidden = get_attribute_value(entity,'hidden')

		#Bulk items are items to inlcude in the list, but have no model
		bulkitems = get_attribute_value(entity,'bulkitems')
		#If the item is hidden, we do not include it in the list
		if item && hidden != 1
			@item_list += [:item => item, :description => description]
		end

		if bulkitems
			temp = bulkitems.split(',')

			temp.each do |item|
				t = item.strip.split('*').first
				q = item.strip.split('*').last
				@item_list += [:item => t, :description => ""]*q.to_i
			end
		end
  end

  # This method format the @report_data string assembled in create_report_string
  # according to the specified file type in @file_type into the @report_string
  #   Args:
  #   	None
  #   Returns:
  #      None
  # Modified to list in a 'bom' style format (item, description, quantity, price, and extended price)

  def write_report_string
      total_price = 0
      # Create the initial string that is our report.
      @report_string = @doc_start

      # Append the "title row" of the report, which is a series of cells that
      # contain the ordered names from @title_array.
      @report_string += @row_start + @cell_start + 'Item' + @cell_mid + 'Description' + @cell_mid + 'Quantity' + @cell_end

	  @report_string += @row_end

	  #Make a list of unique item numbers (consolidated list of items)
	  append_list = @item_list.uniq

		#sort the list and add the formatting text for HTML or CSV
		append_list.sort_by{ |itemlist| itemlist[:item] }.each do |itemlist|

			@report_string += @row_start
			@report_string += @cell_start
			if itemlist[:item]
				@report_string += itemlist[:item]
			else
				""
			end
			@report_string += @cell_mid

			if itemlist[:description]
					@report_string += itemlist[:description]
				else
					@report_string += "---"
			end

			@report_string += @cell_mid
			#Generate the number of times the item number appears in the item list. The is the quantity of items.
			quantity = @item_list.select{|w| w == itemlist}.size
			@report_string += quantity.to_s
			@report_string += @cell_end
			@report_string += @row_end
		end
	  empty_cell = @cell_start + @cell_end
      # Clean up the report data variables to release memory.
      @report_attribute_list = nil
      @title_array = nil
      @report_data = nil
      @totals_by_att_name = nil
  end


  def generate_attributes_report(filename, entities_list)

    # Start an operation so everything performs faster.
    Sketchup.active_model.start_operation 'Generate Report', true
	model = Sketchup.active_model
    view = model.active_view
	#view.zoom_extents
    @filetype = ".html"
	@filename = (model.path.sub(/.skp/,""))+".html"
	@showprice=0

	# Open a save dialog on the last known path, (passing nil as the save path
    # does that automatically.)
		path = UI.savepanel "Save Report", nil, @filename
	if path
		@filename=path
		set_up(@filename)
	else
		return
	end
    #collect all the attributes in the selection or in the model
    collect_attributes(entities_list)

    # This check is to capture the case in which the selection for which we were
    # generating the report did not contain either a Group r a Component
    if write_report_string == -1
      return
    end


    # initialization of all the class variables used
	if ( path.split('.').last == nil)
		path += @filetype
	end


	if (path and path.split('.').last == @filetype)
		begin
			file = File.new(path, "w")
			file.print @report_string
		rescue
			msg = "There was an error saving your report.\n" +
			  "Please make sure it is not open in any other software " +
			  "and try again."
		ensure
		file.close
		#Open the report in the default browser.
		status = UI.openURL @filename
      end

    elsif path.nil == false
      UI.messagebox "You Have changed the filetype in the save dialog, please try again."
    end
    # Select the pricing file you want to use

    # All done, so commit the operation.
    Sketchup.active_model.commit_operation

  end

end


if( not $dcomp_reporter_loaded )

  dcomp_reporter = DCompReporter.new

  # Set up some UI hooks.
  plugins_menu = UI.menu "Plugins"
  plugins_menu.add_item("Generate Summary BOM as HTML") {
    dcomp_reporter.generate_attributes_report("report.html", Sketchup.active_model.entities)
  }


  $dcomp_reporter_loaded = true

end
