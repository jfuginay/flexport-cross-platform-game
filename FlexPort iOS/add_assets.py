#\!/usr/bin/env python3
import re

def generate_id():
    import random
    import string
    chars = string.ascii_uppercase + string.digits
    return ''.join(random.choice(chars) for _ in range(24))

# Read the project file
with open('FlexPort.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Check if Assets.xcassets is already referenced
if 'Assets.xcassets' in content:
    print("Assets.xcassets already in project")
    exit(0)

# Generate unique IDs
assets_file_id = generate_id()
assets_build_id = generate_id()
resources_phase_id = generate_id()

# Add file reference
file_ref_pattern = r'(\s+)(/\* End PBXFileReference section \*/)'
new_file_ref = f'\t\t{assets_file_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = "<group>"; }};'
content = re.sub(file_ref_pattern, rf'{new_file_ref}\n\1\2', content)

# Add build file
build_file_pattern = r'(\s+)(/\* End PBXBuildFile section \*/)'
new_build_file = f'\t\t{assets_build_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_file_id} /* Assets.xcassets */; }};'
content = re.sub(build_file_pattern, rf'{new_build_file}\n\1\2', content)

# Add to FlexPort group
group_pattern = r'(F180DC5AB772B99F43D676EF /\* FlexPort \*/ = \{\s+isa = PBXGroup;\s+children = \(\s+)(CA02AF24552B423B826FD393 /\* FlexPortApp\.swift \*/,)'
content = re.sub(group_pattern, rf'\1{assets_file_id} /* Assets.xcassets */,\n\t\t\t\t\2', content)

# Add Resources build phase
resources_section = f'''
/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase_id} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{assets_build_id} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */
'''

sources_pattern = r'(\s*)(/\* Begin PBXSourcesBuildPhase section \*/)'
content = re.sub(sources_pattern, rf'{resources_section}\n\1\2', content)

# Add resources phase to target build phases
target_pattern = r'(\s+buildPhases = \(\s+4C8A98F07B53F0353F9BF230 /\* Sources \*/,\s+08CDFB8CAE36EEEC75EEA8AB /\* Frameworks \*/,)'
content = re.sub(target_pattern, rf'\1\n\t\t\t\t{resources_phase_id} /* Resources */,', content)

# Write back to file
with open('FlexPort.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("Successfully added Assets.xcassets to Xcode project")
