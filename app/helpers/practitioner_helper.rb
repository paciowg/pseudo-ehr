################################################################################
#
# Practitioner Helper
#
# Copyright (c) 2019 The MITRE Corporation.  All rights reserved.
#
################################################################################

module PractitionerHelper

  def display_qualification(qualification)
    sanitize(qualification.identifier)
  end

  #-----------------------------------------------------------------------------

  def display_period(period)
    period.present? ?
            sanitize('Effective ' + period.start + ' to ' + period.end) : ''
  end

  #-----------------------------------------------------------------------------

  def display_issuer(issuer)
    sanitize(issuer.display)
  end

  #-----------------------------------------------------------------------------

  def display_practitioner_photo(photo, gender, options)
    options[:class] = "img-fluid"
    if photo.present?
      result = image_tag(photo, options)
    else
      result = image_tag(gender == "female" ? 
                  "female-doctor-icon-9.jpg" : "doctor-icon-png-1.jpg", options)
    end

    return result
  end

end
