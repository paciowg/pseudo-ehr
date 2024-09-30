module ApplicationHelper
  include CacheKeysHelper
  include Pagy::Frontend
  # Flash messages tailwind classes for styling
  def tailwind_class_for(flash_type)
    case flash_type.to_sym
    when :success
      'text-green-500 bg-green-100 dark:bg-green-800 dark:text-green-200'
    when :danger
      ' text-red-500 bg-red-100 rounded-lg dark:bg-red-800 dark:text-red-200'
    when :warning
      'text-orange-500 bg-orange-100 dark:bg-orange-700 dark:text-orange-200'
    when :notice
      'text-blue-500 bg-blue-100 dark:bg-blue-800 dark:text-blue-200'
    else
      flash_type.to_s
    end
  end

  def calculate_age(date_string)
    return date_string if date_string == '--'

    birthdate = Date.parse(date_string)
    today = Date.current
    age = today.year - birthdate.year

    # Adjust for a birthday that hasn't occurred this year yet
    age -= 1 if today < birthdate + age.years

    age
  end

  def queries
    session[:queries] ||= []
  end

  def add_query(query)
    queries << query
  end

  def clear_queries
    session[:queries] = []
  end
end
