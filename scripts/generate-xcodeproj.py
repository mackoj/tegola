"""Writes Tegola.xcodeproj (project.pbxproj and the shared scheme) in telaio's shape: objectVersion 77, synchronized
folder groups, every build setting inline, local package references (PLAN §2.4).

    python3 scripts/generate-xcodeproj.py .

Object ids are derived from each object's role, so regenerating gives the same file. Change the project by changing
this script (a new linked product goes in `app_products`), then regenerate and commit both. Opening the project in
Xcode and saving it is fine too; just don't mix the two in one change.
"""
import hashlib, sys, os

def oid(name):
    return hashlib.md5(("tegola:" + name).encode()).hexdigest()[:24].upper()

ROOT = sys.argv[1]
P = oid("project")
APP, UNIT, UI = oid("target.app"), oid("target.unit"), oid("target.ui")
G_MAIN, G_PRODUCTS = oid("group.main"), oid("group.products")
G_APP, G_UNIT, G_UI = oid("sync.app"), oid("sync.unit"), oid("sync.ui")
F_APP, F_UNIT, F_UI = oid("product.app"), oid("product.unit"), oid("product.ui")
CL_P, CL_APP, CL_UNIT, CL_UI = oid("cl.project"), oid("cl.app"), oid("cl.unit"), oid("cl.ui")
LOCAL_FEATURES, LOCAL_DS = oid("local.features"), oid("local.designsystem")
REMOTE_TCA = oid("remote.tca")
DEP_UNIT_PROXY, DEP_UI_PROXY = oid("proxy.unit"), oid("proxy.ui")
DEP_UNIT, DEP_UI = oid("dep.unit"), oid("dep.ui")

# (product, package reference or None for local) linked by the app
app_products = [("AppFeature", None), ("ComposableArchitecture", REMOTE_TCA), ("TegolaDesignSystem", None), ("TegolaDesignTokens", None)]
prod_dep = {n: oid("productdep." + n) for n, _ in app_products}
build_file = {n: oid("buildfile." + n) for n, _ in app_products}

phases = {k: oid("phase." + k) for k in ["app.sources", "app.frameworks", "app.resources", "unit.sources", "unit.frameworks", "unit.resources", "ui.sources", "ui.frameworks", "ui.resources"]}

def cfg(name):
    return oid("cfg." + name)

common_project = """				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ENABLE_MODULES = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES;
				SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 1;
"""
debug_project = common_project + """				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""
release_project = common_project + """				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
"""
app_settings = """				CODE_SIGN_ENTITLEMENTS = Tegola/Tegola.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Tegola;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.lifestyle";
				INFOPLIST_KEY_NSCameraUsageDescription = "Tegola uses the camera to read barcodes and labels and to photograph your objects. Photos stay on your iPhone.";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Tegola adds the photos you choose to your objects. They stay on your iPhone.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 0.1;
				PRODUCT_BUNDLE_IDENTIFIER = fr.macko.tegola;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
"""
unit_settings = """				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 0.1;
				PRODUCT_BUNDLE_IDENTIFIER = fr.macko.tegola.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Tegola.app/Tegola";
"""
ui_settings = """				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 0.1;
				PRODUCT_BUNDLE_IDENTIFIER = fr.macko.tegola.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				TEST_TARGET_NAME = Tegola;
"""

def conf(key, name, settings):
    return f"""		{cfg(key)} /* {name} */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{settings}			}};
			name = {name};
		}};
"""

def phase(key, isa, name, files=()):
    body = "".join(f"\t\t\t\t{f},\n" for f in files)
    return f"""		{phases[key]} /* {name} */ = {{
			isa = {isa};
			buildActionMask = 2147483647;
			files = (
{body}			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""

def target(tid, name, cl, keys, group, product, ptype, deps=(), proddeps=()):
    p = "".join(f"\t\t\t\t{phases[k]},\n" for k in keys)
    d = "".join(f"\t\t\t\t{x},\n" for x in deps)
    pd = "".join(f"\t\t\t\t{x} /* {n} */,\n" for n, x in proddeps)
    return f"""		{tid} /* {name} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {cl};
			buildPhases = (
{p}			);
			buildRules = (
			);
			dependencies = (
{d}			);
			fileSystemSynchronizedGroups = (
				{group} /* {name} */,
			);
			name = {name};
			packageProductDependencies = (
{pd}			);
			productName = {name};
			productReference = {product} /* {name}{'.app' if ptype.endswith('application"') else '.xctest'} */;
			productType = {ptype};
		}};
"""

out = []
w = out.append
w("""// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
""")
for n, _ in app_products:
    w(f"\t\t{build_file[n]} /* {n} in Frameworks */ = {{isa = PBXBuildFile; productRef = {prod_dep[n]} /* {n} */; }};\n")
w("""/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
""")
for proxy in (DEP_UNIT_PROXY, DEP_UI_PROXY):
    w(f"""		{proxy} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {P} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {APP};
			remoteInfo = Tegola;
		}};
""")
w(f"""/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		{F_APP} /* Tegola.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Tegola.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{F_UNIT} /* TegolaTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TegolaTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{F_UI} /* TegolaUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TegolaUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{G_APP} /* Tegola */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = Tegola;
			sourceTree = "<group>";
		}};
		{G_UNIT} /* TegolaTests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = TegolaTests;
			sourceTree = "<group>";
		}};
		{G_UI} /* TegolaUITests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = TegolaUITests;
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
""")
w(phase("app.frameworks", "PBXFrameworksBuildPhase", "Frameworks", [f"{build_file[n]} /* {n} in Frameworks */" for n, _ in app_products]))
w(phase("unit.frameworks", "PBXFrameworksBuildPhase", "Frameworks"))
w(phase("ui.frameworks", "PBXFrameworksBuildPhase", "Frameworks"))
w(f"""/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{G_MAIN} = {{
			isa = PBXGroup;
			children = (
				{G_APP} /* Tegola */,
				{G_UNIT} /* TegolaTests */,
				{G_UI} /* TegolaUITests */,
				{G_PRODUCTS} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{G_PRODUCTS} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{F_APP} /* Tegola.app */,
				{F_UNIT} /* TegolaTests.xctest */,
				{F_UI} /* TegolaUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
""")
w(target(APP, "Tegola", CL_APP, ["app.sources", "app.frameworks", "app.resources"], G_APP, F_APP, '"com.apple.product-type.application"', proddeps=[(n, prod_dep[n]) for n, _ in app_products]))
w(target(UNIT, "TegolaTests", CL_UNIT, ["unit.sources", "unit.frameworks", "unit.resources"], G_UNIT, F_UNIT, '"com.apple.product-type.bundle.unit-test"', deps=[f"{DEP_UNIT} /* PBXTargetDependency */"]))
w(target(UI, "TegolaUITests", CL_UI, ["ui.sources", "ui.frameworks", "ui.resources"], G_UI, F_UI, '"com.apple.product-type.bundle.ui-testing"', deps=[f"{DEP_UI} /* PBXTargetDependency */"]))
w(f"""/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{P} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2700;
				LastUpgradeCheck = 2700;
				TargetAttributes = {{
					{APP} = {{
						CreatedOnToolsVersion = 27.1;
					}};
					{UNIT} = {{
						CreatedOnToolsVersion = 27.1;
						TestTargetID = {APP};
					}};
					{UI} = {{
						CreatedOnToolsVersion = 27.1;
						TestTargetID = {APP};
					}};
				}};
			}};
			buildConfigurationList = {CL_P} /* Build configuration list for PBXProject "Tegola" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
				fr,
			);
			mainGroup = {G_MAIN};
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				{REMOTE_TCA} /* XCRemoteSwiftPackageReference "swift-composable-architecture" */,
				{LOCAL_FEATURES} /* XCLocalSwiftPackageReference "Packages/TegolaFeatures" */,
				{LOCAL_DS} /* XCLocalSwiftPackageReference "Packages/TegolaDesignSystem" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = {G_PRODUCTS} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{APP} /* Tegola */,
				{UNIT} /* TegolaTests */,
				{UI} /* TegolaUITests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
""")
w(phase("app.resources", "PBXResourcesBuildPhase", "Resources"))
w(phase("unit.resources", "PBXResourcesBuildPhase", "Resources"))
w(phase("ui.resources", "PBXResourcesBuildPhase", "Resources"))
w("""/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
""")
w(phase("app.sources", "PBXSourcesBuildPhase", "Sources"))
w(phase("unit.sources", "PBXSourcesBuildPhase", "Sources"))
w(phase("ui.sources", "PBXSourcesBuildPhase", "Sources"))
w(f"""/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{DEP_UNIT} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {APP} /* Tegola */;
			targetProxy = {DEP_UNIT_PROXY} /* PBXContainerItemProxy */;
		}};
		{DEP_UI} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {APP} /* Tegola */;
			targetProxy = {DEP_UI_PROXY} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
""")
w(conf("project.debug", "Debug", debug_project))
w(conf("project.release", "Release", release_project))
w(conf("app.debug", "Debug", app_settings))
w(conf("app.release", "Release", app_settings))
w(conf("unit.debug", "Debug", unit_settings))
w(conf("unit.release", "Release", unit_settings))
w(conf("ui.debug", "Debug", ui_settings))
w(conf("ui.release", "Release", ui_settings))
w("""/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
""")
for cl, label, key in [(CL_P, 'PBXProject "Tegola"', "project"), (CL_APP, 'PBXNativeTarget "Tegola"', "app"), (CL_UNIT, 'PBXNativeTarget "TegolaTests"', "unit"), (CL_UI, 'PBXNativeTarget "TegolaUITests"', "ui")]:
    w(f"""		{cl} /* Build configuration list for {label} */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{cfg(key + '.debug')} /* Debug */,
				{cfg(key + '.release')} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
""")
w(f"""/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{LOCAL_FEATURES} /* XCLocalSwiftPackageReference "Packages/TegolaFeatures" */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/TegolaFeatures;
		}};
		{LOCAL_DS} /* XCLocalSwiftPackageReference "Packages/TegolaDesignSystem" */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/TegolaDesignSystem;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCRemoteSwiftPackageReference section */
		{REMOTE_TCA} /* XCRemoteSwiftPackageReference "swift-composable-architecture" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/pointfreeco/swift-composable-architecture";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 1.26.0;
			}};
		}};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
""")
for n, pkg in app_products:
    pkgline = f"\n\t\t\tpackage = {pkg} /* XCRemoteSwiftPackageReference \"swift-composable-architecture\" */;" if pkg else ""
    w(f"""		{prod_dep[n]} /* {n} */ = {{
			isa = XCSwiftPackageProductDependency;{pkgline}
			productName = {n};
		}};
""")
w(f"""/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {P} /* Project object */;
}}
""")
os.makedirs(f"{ROOT}/Tegola.xcodeproj/xcshareddata/xcschemes", exist_ok=True)
open(f"{ROOT}/Tegola.xcodeproj/project.pbxproj", "w").write("".join(out))

scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2700" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{APP}" BuildableName = "Tegola.app" BlueprintName = "Tegola" ReferencedContainer = "container:Tegola.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO" parallelizable = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{UNIT}" BuildableName = "TegolaTests.xctest" BlueprintName = "TegolaTests" ReferencedContainer = "container:Tegola.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference skipped = "NO" parallelizable = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{UI}" BuildableName = "TegolaUITests.xctest" BlueprintName = "TegolaUITests" ReferencedContainer = "container:Tegola.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{APP}" BuildableName = "Tegola.app" BlueprintName = "Tegola" ReferencedContainer = "container:Tegola.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{APP}" BuildableName = "Tegola.app" BlueprintName = "Tegola" ReferencedContainer = "container:Tegola.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
open(f"{ROOT}/Tegola.xcodeproj/xcshareddata/xcschemes/Tegola.xcscheme", "w").write(scheme)
print("written")
