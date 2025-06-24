FactoryBot.define do
  factory :task_status do
    task_id { 'MyString' }
    task_type { 'MyString' }
    status { 'MyString' }
    message { 'MyText' }
    folder_path { 'MyString' }
    server_url { 'MyString' }
  end
end
