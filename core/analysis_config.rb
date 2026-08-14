
require_relative 'tolerance'

module SUAnalysis
  module Core
    #
    # AnalysisConfig — the single object every analyzer reads from.
    #
    # PI_TASK_001 §9 / §10 require a "统一配置入口 ... 集中管理 ... 方便以后通过
    # Company Profile 调整"。AnalysisConfig IS that entry. Profile objects in
    # Stage 4 will construct AnalysisConfig from persisted settings.
    #
    # Currently no computation lives here; analyzers read `config.tolerance`
    # and friends. This is intentional — profiles hook in by replacing the
    # AnalysisConfig instance, not by editing analyzers.
    #
    class AnalysisConfig
      attr_reader :tolerance, :profile_name, :deepest_nesting_warning

      def initialize(tolerance: Tolerance.default, profile_name: 'default', deepest_nesting_warning: 3)
        @tolerance                = tolerance
        @profile_name             = profile_name.to_s
        @deepest_nesting_warning  = deepest_nesting_warning.to_i
      end

      def to_h
        {
          tolerance:               @tolerance.to_h,
          profile_name:            @profile_name,
          deepest_nesting_warning: @deepest_nesting_warning
        }
      end
    end
  end
end
