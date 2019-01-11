module Secretary
  module HasSecretary
    extend ActiveSupport::Concern

    module ClassMethods
      # Check if a class is versioned
      #
      # Example
      #
      #   Story.has_secretary? # => true or false
      #
      # Returns boolean
      def has_secretary?
        !!@_has_secretary
      end

      # Declare that this class should be versioned.
      #
      # Arguments
      #
      # * options (Hash) -
      #   * `on` (Array)      - Array of Strings which specifies which
      #                         attributes should be versioned.
      #   * `except` (Array)  - Array of Strings which specifies which
      #                         attributes should NOT be versioned.
      #
      # Examples
      #
      #   has_secretary on: ["published_at", "user_id"]
      #   has_secretary except: ["id", "created_at"]
      #
      # Returns nothing
      def has_secretary(options={})
        @_has_secretary = true
        Secretary.versioned_models.push self.name

        self.versioned_attributes   = options[:on]     if options[:on]
        self.unversioned_attributes = options[:except] if options[:except]

        has_many :versions,
          :class_name   => "Secretary::Version",
          :as           => :versioned,
          :dependent    => :delete_all

        attr_accessor :logged_user_id

        after_save :generate_version,
          :if => lambda { __versioned_changes.present? }

        after_save :reset_versioned_changes

        include InstanceMethodsOnActivation
      end
    end


    module InstanceMethodsOnActivation
      # Generate a version for this object.
      #
      # Returns nothing
      def generate_version
        Version.generate(self)
      end
    end
  end
end
