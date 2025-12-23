module Mcp
  module Tools
    class Base
      def initialize(project_id)
        @project_id = project_id
      end

      def call(args)
        raise NotImplementedError
      end
    end
  end
end
