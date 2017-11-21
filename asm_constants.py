import argparse
import re

ArgP = argparse.ArgumentParser(description='Copy all constants to a seperate file.')
ArgP.add_argument('sourcePath', metavar='source', type=str, help='Path to the source file')
ArgP.add_argument('targetPath', metavar='target', type=str, help='Path to the target file')
ArgP.add_argument('-i', action='store_true', help='Print debugging info')
Args = ArgP.parse_args()

info = Args.i

const_prefix = '%ifndef\s+PPP_AUTO_CONSTANT;const'
const_suffix = '%endif;const'
const_remove = const_prefix + '\s*|\s*' + const_suffix
const_full = const_prefix + '.*' + const_suffix
include = '%include\s+'

def ParseFile(path):
    global info
    global const_prefix
    global const_suffix
    global const_remove
    global const_full
    global include
    if info:
        print(path)
    sourceFile = open(path, 'r')
    source = sourceFile.read()
    sourceFile.close()
    constants = re.findall(const_full, source, re.DOTALL)
    if len(constants) > 0:
        if info:
            print('\tcontains constants')
        targetFile.write('\n;' + path)
        for c in constants:
            targetFile.write('\n' + re.sub(const_remove, '',  c) + '\n')
    elif info:
        print("\tdoesn't contain constants")
    includes = re.findall(include + '.*', source)
    for inc in includes:
        ParseFile(re.sub(include, '', inc)[1:-1]) #remove path quotes

targetFile = open(Args.targetPath, 'w')
targetFile.write('%define PPP_AUTO_CONSTANT\n')
ParseFile(Args.sourcePath)
targetFile.close()
