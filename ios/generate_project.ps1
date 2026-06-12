# PowerShell script to generate Xcode project file (.xcodeproj) on Windows

$projectDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($projectDir)) {
    $projectDir = Get-Location
}

$xcodeprojDir = Join-Path $projectDir "ScamCall.xcodeproj"
$null = New-Item -ItemType Directory -Force -Path $xcodeprojDir

# Define files in the project
$swiftFiles = @(
    "ScamCallApp.swift",
    "ContentView.swift",
    "LiveMonitorView.swift",
    "KnowledgeBaseView.swift",
    "IncidentReportsView.swift",
    "SettingsView.swift",
    "SkepticismEngine.swift",
    "AppDatabase.swift",
    "CallDirectoryHandler.swift",
    "MessageFilterExtension.swift"
)

# Helper to generate a valid 24-character hexadecimal UUID
function Get-UUID ($name) {
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($name)
    $hash = $sha1.ComputeHash($bytes)
    $hex = ($hash | ForEach-Object { $_.ToString("X2") }) -join ""
    return $hex.Substring(0, 24)
}

# Generate UUID maps
$fileRefs = @{}
$buildFiles = @{}

foreach ($f in $swiftFiles) {
    $fileRefs[$f] = Get-UUID ($f + "_fileref")
    $buildFiles[$f] = Get-UUID ($f + "_buildfile")
}

$projectUuid = Get-UUID "scamcall_project"
$targetUuid = Get-UUID "scamcall_target"
$mainGroupUuid = Get-UUID "scamcall_main_group"
$sourcesGroupUuid = Get-UUID "scamcall_sources_group"
$productsGroupUuid = Get-UUID "scamcall_products_group"
$appProductUuid = Get-UUID "scamcall_app_product"
$appProductFileRef = Get-UUID "scamcall_app_product_file_ref"

$sourcesBuildPhaseUuid = Get-UUID "scamcall_sources_build_phase"
$frameworksBuildPhaseUuid = Get-UUID "scamcall_frameworks_build_phase"
$resourcesBuildPhaseUuid = Get-UUID "scamcall_resources_build_phase"

$projConfigListUuid = Get-UUID "scamcall_proj_config_list"
$targetConfigListUuid = Get-UUID "scamcall_target_config_list"

$projDebugConfigUuid = Get-UUID "scamcall_proj_debug_config"
$projReleaseConfigUuid = Get-UUID "scamcall_proj_release_config"
$targetDebugConfigUuid = Get-UUID "scamcall_target_debug_config"
$targetReleaseConfigUuid = Get-UUID "scamcall_target_release_config"

# Assemble pbxproj content
$pbxproj = @"
// !`$`*UTF8`$`*`!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
"@

foreach ($f in $swiftFiles) {
    $bUuid = $buildFiles[$f]
    $fUuid = $fileRefs[$f]
    $pbxproj += "`t`t$bUuid /* $f in Sources */ = {isa = PBXBuildFile; fileRef = $fUuid /* $f */; };`n"
}

$pbxproj += @"
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"@

foreach ($f in $swiftFiles) {
    $fUuid = $fileRefs[$f]
    $pbxproj += "`t`t$fUuid /* $f */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $f; sourceTree = `"<group>`"; };`n"
}

$pbxproj += "`t`t$appProductFileRef /* ScamCall.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ScamCall.app; sourceTree = BUILT_PRODUCTS_DIR; };`n"

$pbxproj += @"
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		$frameworksBuildPhaseUuid /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		$mainGroupUuid = {
			isa = PBXGroup;
			children = (
				$sourcesGroupUuid /* ScamCall */,
				$productsGroupUuid /* Products */,
			);
			sourceTree = `"<group>`";
		};
		$sourcesGroupUuid /* ScamCall */ = {
			isa = PBXGroup;
			children = (
"@

foreach ($f in $swiftFiles) {
    $fUuid = $fileRefs[$f]
    $pbxproj += "`t`t`t`t$fUuid /* $f */,`n"
}

$pbxproj += @"
			);
			path = ScamCall;
			sourceTree = `"<group>`";
		};
		$productsGroupUuid /* Products */ = {
			isa = PBXGroup;
			children = (
				$appProductFileRef /* ScamCall.app */,
			);
			name = Products;
			sourceTree = `"<group>`";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		$targetUuid /* ScamCall */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = $targetConfigListUuid /* Build configuration list for PBXNativeTarget "ScamCall" */;
			buildPhases = (
				$sourcesBuildPhaseUuid /* Sources */,
				$frameworksBuildPhaseUuid /* Frameworks */,
				$resourcesBuildPhaseUuid /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = ScamCall;
			productName = ScamCall;
			productReference = $appProductFileRef /* ScamCall.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		$projectUuid /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					$targetUuid = {
						CreatedOnToolsVersion = 15.0;
						LastSwiftMigration = 1500;
					};
				};
			};
			buildConfigurationList = $projConfigListUuid /* Build configuration list for PBXProject "ScamCall" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = $mainGroupUuid;
			productRefGroup = $productsGroupUuid /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				$targetUuid /* ScamCall */,
			);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		$sourcesBuildPhaseUuid /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
"@

foreach ($f in $swiftFiles) {
    $bUuid = $buildFiles[$f]
    $pbxproj += "`t`t`t`t$bUuid /* $f in Sources */,`n"
}

$pbxproj += @"
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
		$resourcesBuildPhaseUuid /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		$projDebugConfigUuid /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_REPRODUCIBLE_ACTIONS = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"`$`(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		$projReleaseConfigUuid /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_CXX_LIBRARY = "libc++";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_REPRODUCIBLE_ACTIONS = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = {
					isa = XCBuildConfiguration;
					buildSettings = {
						ALWAYS_SEARCH_USER_PATHS = NO;
						ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
						CLANG_ANALYZER_NONNULL = YES;
						CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
						CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
						CLANG_CXX_LIBRARY = "libc++";
						CLANG_ENABLE_MODULES = YES;
						CLANG_ENABLE_OBJC_ARC = YES;
						CLANG_ENABLE_OBJC_WEAK = YES;
						CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
						CLANG_WARN_BOOL_CONVERSION = YES;
						CLANG_WARN_COMMA = YES;
						CLANG_WARN_CONSTANT_CONVERSION = YES;
						CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
						CLANG_WARN_DIRECT_OBJC_REPRODUCIBLE_ACTIONS = YES;
						CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
						CLANG_WARN_EMPTY_BODY = YES;
						CLANG_WARN_ENUM_CONVERSION = YES;
						CLANG_WARN_INFINITE_RECURSION = YES;
						CLANG_WARN_INT_CONVERSION = YES;
						CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
						CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
						CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
						CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
						CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
						CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
						CLANG_WARN_STRICT_PROTOTYPES = YES;
						CLANG_WARN_SUSPICIOUS_MOVE = YES;
						CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
						CLANG_WARN_UNREACHABLE_CODE = YES;
						COPY_PHASE_STRIP = NO;
						DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
						ENABLE_NS_ASSERTIONS = NO;
						ENABLE_STRICT_OBJC_MSGSEND = YES;
						ENABLE_USER_SCRIPT_SANDBOXING = YES;
						GCC_C_LANGUAGE_STANDARD = gnu17;
						GCC_NO_COMMON_BLOCKS = YES;
						GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
						GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
						GCC_WARN_UNDECLARED_SELECTOR = YES;
						GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
						GCC_WARN_UNUSED_FUNCTION = YES;
						GCC_WARN_UNUSED_VARIABLE = YES;
						IPHONEOS_DEPLOYMENT_TARGET = 17.0;
						MTL_ENABLE_DEBUG_INFO = NO;
						MTL_FAST_MATH = YES;
						SDKROOT = iphoneos;
						SWIFT_COMPILATION_MODE = wholemodule;
						SWIFT_OPTIMIZATION_LEVEL = "-O";
						VALIDATE_PRODUCT = YES;
					};
					name = Release;
				};
			};
			name = Release;
		};
		$targetDebugConfigUuid /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				INFOPLIST_KEY_CFBundleDisplayName = ScamCall;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities";
				LD_RUNPATH_SEARCH_PATHS = (
					"`$`(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.scamcall.app;
				PRODUCT_NAME = "`$`(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		$targetReleaseConfigUuid /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				INFOPLIST_KEY_CFBundleDisplayName = ScamCall;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities";
				LD_RUNPATH_SEARCH_PATHS = (
					"`$`(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.scamcall.app;
				PRODUCT_NAME = "`$`(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		$projConfigListUuid /* Build configuration list for PBXProject "ScamCall" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$projDebugConfigUuid /* Debug */,
				$projReleaseConfigUuid /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		$targetConfigListUuid /* Build configuration list for PBXNativeTarget "ScamCall" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				$targetDebugConfigUuid /* Debug */,
				$targetReleaseConfigUuid /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = $projectUuid /* Project object */;
}
"@

$pbxprojPath = Join-Path $xcodeprojDir "project.pbxproj"
[System.IO.File]::WriteAllText($pbxprojPath, $pbxproj, [System.Text.Encoding]::UTF8)

Write-Host "Xcode project structure generated successfully at: $xcodeprojDir"
