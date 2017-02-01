module Secretary
  class Version < ActiveRecord::Base

    #monkey patch

    self.table_name = "secretary_versions"
    acts_as_paranoid

    belongs_to :version_object_change, dependent: :destroy, inverse_of: :version

    validates :versioned, presence: true
    validates :version_object_change, presence: true, uniqueness: true

    before_validation(on: :create) {
      set_values
    }
    before_create do
      set_version_number
    end

    ##

    serialize :object_changes

    belongs_to :versioned, :polymorphic => true
    belongs_to :user, :class_name => Secretary.config.user_class

    validates_presence_of :versioned

    before_create :increment_version_number

    ##monkey patch

    def object_changes
      version_object_change&.object_changes
    end

    def object_changes=(oc)
      get_version_object_change.object_changes = oc
    end

    def get_version_object_change
      self.version_object_change || self.build_version_object_change
    end

    private

    def set_values
      self.user_id ||= RequestStore.store[:current_user_id]
      self.change_type ||= get_change_type
      self.account_id ||= get_account_id
      self.versioned_class_name = self.versioned.class.name
      get_version_object_change
    end

    def set_version_number
      latest_version = self.class.unscoped.where(versioned: versioned).order("version_number").last
      self.version_number = latest_version.try(:version_number).to_i + 1
    end

    def get_change_type
      action = description.to_s.downcase.split.first.to_s
      case action
      when "created", "destroyed"
        action
      when "changed"
        "updated"
      end
    end

    def get_account_id
      if versioned.respond_to? :account_id
        versioned.account_id
      end
    end

    ##

    class << self
      # Builds a new version for the passed-in object
      # Passed-in object is a dirty object.
      # Version will be saved when the object is saved.
      #
      # If you must generate a version manually, this
      # method should be used instead of `Version.create`.
      # I didn't want to override the public ActiveRecord
      # API.
      def generate(object)
        changes = object.send(:__versioned_changes)

        object.versions.create({
          :user_id          => object.logged_user_id,
          :description      => generate_description(object, changes.keys),
          :object_changes   => changes
        })
      end


      private

      def generate_description(object, attributes)
        changed_attributes = attributes.map(&:humanize).to_sentence

        if was_created?(object)
          "Created #{object.class.name.titleize} ##{object.id}"

        elsif was_updated?(object)
          "Changed #{changed_attributes}"

        else
          "Generated Version"
        end
      end


      def was_created?(object)
        object.persisted? && object.id_changed?
      end

      def was_updated?(object)
        object.persisted? && !object.id_changed?
      end
    end


    # The attribute diffs for this version
    def attribute_diffs
      @attribute_diffs ||= begin
                             changes           = self.object_changes.dup
                             attribute_diffs   = {}

                             # Compare each of object_b's attributes to object_a's attributes
                             # And if there is a difference, add it to the Diff
                             changes.each do |attribute, values|
                               # values is [previous_value, new_value]
                               diff = Diffy::Diff.new(values[0].to_s, values[1].to_s)
                               attribute_diffs[attribute] = diff
                             end

                             attribute_diffs
                           end
    end

    # A simple title for this version.
    # Example: "Article #125 v6"
    def title
      "#{self.versioned.class.name.titleize} " \
        "##{self.versioned.id} v#{self.version_number}"
    end


    private

    def increment_version_number
      latest_version = self.versioned.versions.order("version_number").last
      self.version_number = latest_version.try(:version_number).to_i + 1
    end
  end
end
