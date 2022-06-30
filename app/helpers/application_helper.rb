################################################################################
#
# Application Helper
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

module ApplicationHelper

  # Determines the CSS class of the flash message for display from the
  # specified level.

  def flash_class(level)
    case level
    when 'notice'
      css_class = 'alert-info'
    when 'success'
      css_class = 'alert-success'
    when 'error'
      css_class = 'alert-danger'
    when 'alert'
      css_class = 'alert-danger'
    end

    css_class
  end

	#-----------------------------------------------------------------------------

	def display_human_name(name)
	  if name
		human_name = [name.prefix.join(', '), name.given.join(' '), name.family].join(' ')
		human_name += ', ' + name.suffix.join(', ') if name.suffix.present?
		sanitize(human_name) 
	  end
	  
	end

	#-----------------------------------------------------------------------------

	def display_photo(photo, gender, options)
    options[:class] = 'img-fluid'
 		if photo.present?
			result = image_tag(photo, options)
		else
			result = image_tag(gender == "female" ? "woman.svg" : "man-user.svg", options)
		end

		return result
	end

	#-----------------------------------------------------------------------------

	def display_telecom(telecom)
	  sanitize(telecom.system + ': ' + number_to_phone(telecom.value, area_code: true))
	end

	#-----------------------------------------------------------------------------

	def display_marital_status(marital_status)
		marital_status_values = {
			A: 'Annulled Marriage',
			D: 'Divorced',
			I: 'Interlocutory Subject',
			L: 'Legally Separated',
			M: 'Married',
			C: 'Common Law',
			P: 'Polygamous',
			T: 'Domestic Partner',
			U: 'Unmarried',
			S: 'Never Married',
			W: 'Widowed'
		}
		unless marital_status.nil?
			marital_status_values[marital_status.coding.first.code.to_sym] ||
				sanitize(marital_status.coding.first.code)
		end
		return nil
	end

	#-----------------------------------------------------------------------------

	def display_identifier(identifier)
	  sanitize("#{identifier.assigner.display}: ( #{identifier.type.text}, #{identifier.value})")
	#    sanitize([identifier.type.text, identifier.value, identifier.assigner.display].join(', '))
	end

	#-----------------------------------------------------------------------------

	# Concatenates a list of display elements.

	def display_list(list)
	  sanitize(list.empty? ? 'None' : list.map(&:display).join(', '))
	end

  #-----------------------------------------------------------------------------

  def display_categories(categories)
  	result = []
  	categories.each do |category|
  		result << display_coding_list(category.coding)
  	end

    result = sanitize(result.join('<br />'))
  end

  #-----------------------------------------------------------------------------

  def display_code(code)
    sanitize("#{code.coding[0].display} (#{code.coding[0].code})") if code
  end

	#-----------------------------------------------------------------------------

	# Concatenates a list of code elements.

	def display_code_list(list)
	  sanitize(list.empty? ? 'None' : list.map(&:code).join(', '))
	end

	#-----------------------------------------------------------------------------

	# Concatenates a list of coding display elements.

	def display_coding_list(list)
	  if list.empty?
	    result = 'None'
	  else
	    result = []
	    list.map(&:coding).each do |coding|
	      result << coding.map(&:display)
	    end

	    result = result.join(', ')
	  end

	  sanitize(result)
	end

	#-----------------------------------------------------------------------------

	def google_maps(address)
    if address.text.present?
    	address_text = address.text
    else
    	address_text = (address.line + 
    										[ address.city, address.state, address.postalCode ]).join(', ')
    end

	  'https://www.google.com/maps/search/' + html_escape(address_text)
	end

  #-----------------------------------------------------------------------------

  def address_text(address)
    address_text = (address.line + [ address.city, address.state, address.postalCode ]).join(', ')
  end

	#-----------------------------------------------------------------------------

	def display_postal_code(postal_code)
	  unless postal_code.nil?
	  	sanitize(postal_code.match(/^\d{9}$/) ?
	      postal_code.strip.sub(/([A-Z0-9]+)([A-Z0-9]{4})/, '\1-\2') : postal_code)
	  end
	end

	#-----------------------------------------------------------------------------

	def display_reference(reference)
	  if reference.present?
	    components = reference.reference.split('/')
	    controller = components.first.underscore.pluralize

	    sanitize(link_to(reference.display,
	                     [ '/', controller, '/', components.last ].join))
	  end
	end

  #-----------------------------------------------------------------------------

  def display_raw_date(string)
  	display_date(DateTime.parse(string)) unless string.nil?
  end

  #-----------------------------------------------------------------------------

	def display_date(datetime)
		datetime.present? ? sanitize(datetime.strftime('%m/%d/%Y')) : "No date"
	end

	#-----------------------------------------------------------------------------

	def display_datetime(datetime)
		datetime.present? ? sanitize(datetime.strftime('%m/%d/%Y %I:%M%p')) : "No date/time"
	end

	#-----------------------------------------------------------------------------

	def display_categories(categories)
		sanitize(categories.each.map { |category| category.coding[0].code }.join(', '))	
	end

  #-----------------------------------------------------------------------------

  def display_hash(hash)
    result = []
    hash.each_pair do |key, value|
      if Hash == value.class
        result << display_hash(value)
      elsif Array == value.class
        result << display_array(value)
      else
        result << "#{key}: #{value}"
      end
    end

    result = sanitize(result.join('<br />'))
  end

  #-----------------------------------------------------------------------------

  def display_array(array)
    result = []
    array.each do |value|
      if Hash == value.class
        result << display_hash(value)
      elsif Array == value.class
        result << display_array(value)
      else
        result << value
      end
    end
    
    result = sanitize(result.join('<br />'))
  end

	#-----------------------------------------------------------------------------

	def display_subject(subject)
		display_reference(subject)
	end

	#-----------------------------------------------------------------------------

	def display_performers(performers)
		list = []

		performers.each do |performer|
			list << display_reference(performer)
		end

		raw(list.join('<br />'))
	end

	#-----------------------------------------------------------------------------

	def display_div(div)
		sanitize(div)
	end

  #-----------------------------------------------------------------------------

	def get_id(url)
		if url
			components = url.split('/')
			sanitize(components.last)
		end
		
	end

  #-----------------------------------------------------------------------------

	def get_type(url)
		if url
			components = url.split('/')
			sanitize(components[components.length-2])
		end
		
	end

  #-----------------------------------------------------------------------------

	def get_type_and_id(url)
		if url
		  components = url.split('/')
		  max_index = components.length - 1
		  return [components[max_index-1], components[max_index]].join('/')
	  end
	  
	end

  #-----------------------------------------------------------------------------

	def uri?(string)
		uri = URI.parse(string)
		%w( http https ).include?(uri.scheme)
	  rescue URI::BadURIError
		false
	  rescue URI::InvalidURIError
		false
	end

  #-----------------------------------------------------------------------------

	def get_object_from_id(reference, fhir_client)
		fhir_object = fhir_client.read(nil, reference).resource

    # WARN: constantize may not be safe
    	class_string = get_type(reference)&.constantize

		return class_string.new(fhir_object)
	end

  #-----------------------------------------------------------------------------

	def get_object_from_url(reference_string, fhir_client)
		fhir_object = fhir_client.read(nil, get_type_and_id(reference_string)).resource

    # WARN: constantize may not be safe
    	class_string = get_type(reference_string)&.constantize
    
		return class_string.new(fhir_object) if fhir_object
	end

  #-----------------------------------------------------------------------------

	def get_object_from_url_with_client(reference_string, fhir_client)
		fhir_object = fhir_client.read(nil, [get_type(reference_string), 
                              get_id(reference_string)].join('/')).resource

    # WARN: constantize may not be safe
    class_string = get_type(reference_string).constantize

		return class_string.new(fhir_object, fhir_client)
	end
	
end
