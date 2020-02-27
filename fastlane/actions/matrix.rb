require 'matrix_sdk'

module Fastlane
  module Actions
    module SharedValues
      MATRIX_CUSTOM_VALUE = :MATRIX_CUSTOM_VALUE
    end

    class MatrixAction < Action
      def self.run(params)
        client = MatrixSdk::Client.new 'https://matrix.org'
        client.api.access_token = params[:access_token]
        # UI.message "Account is a member of #{client.rooms.count} rooms"

        room = client.find_room params[:room_id]
        if room.nil?
          UI.user_error!("Room #{params[:room_id]} not found. Please make sure the account is already a member of this room.")
        else
          room.send_text "It works! ✅"
        end

        # sh "shellcommand ./path"

        # Actions.lane_context[SharedValues::MATRIX_CUSTOM_VALUE] = "my_val"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          # FastlaneCore::ConfigItem.new(key: :api_token,
          #                              env_name: "FL_MATRIX_API_TOKEN", # The name of the environment variable
          #                              description: "API Token for MatrixAction", # a short description of this parameter
          #                              verify_block: proc do |value|
          #                                 UI.user_error!("No API token for MatrixAction given, pass using `api_token: 'token'`") unless (value and not value.empty?)
          #                                 # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
          #                              end),
          # FastlaneCore::ConfigItem.new(key: :development,
          #                              env_name: "FL_MATRIX_DEVELOPMENT",
          #                              description: "Create a development certificate instead of a distribution one",
          #                              is_string: false, # true: verifies the input is a string, false: every kind of value
          #                              default_value: false) # the default value if the user didn't provide one
          FastlaneCore::ConfigItem.new(key: :access_token,
                                       env_name: "FL_MATRIX_ACCESS_TOKEN",
                                       description: "Access token for Matrix action",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :room_id,
                                       env_name: "FL_MATRIX_ROOM_ID",
                                       description: "Room ID to send a notification in",
                                       is_string: true),
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['MATRIX_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["kiliankoe"]
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #
        true
      end
    end
  end
end
