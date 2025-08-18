#!/usr/bin/env python3
"""
Comprehensive script to fix ALL lambda errors in combat_manager.gd
Replaces standalone lambda functions with assigned variables
"""

import re

def fix_all_lambda_errors(file_path):
    """Fix all lambda errors in the file"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to find standalone lambda functions in tween_callback
    # This matches: tween_callback(func(): ... )
    lambda_pattern = r'tween_callback\(func\(\):\s*([^}]+)\)'
    
    def replace_lambda(match):
        lambda_body = match.group(1).strip()
        
        # Generate a unique variable name
        import uuid
        var_name = f"lambda_callback_{str(uuid.uuid4())[:8]}"
        
        # Create the replacement
        replacement = f"""# Create callback function
        var {var_name} = func():
            {lambda_body}
        
        tween_callback({var_name})"""
        
        return replacement
    
    # Apply the fix
    fixed_content = re.sub(lambda_pattern, replace_lambda, content)
    
    # Also fix timeout.connect(lambda) patterns
    timeout_pattern = r'timeout\.connect\(func\(\):\s*([^}]+)\)'
    
    def replace_timeout_lambda(match):
        lambda_body = match.group(1).strip()
        
        # Generate a unique variable name
        import uuid
        var_name = f"timeout_callback_{str(uuid.uuid4())[:8]}"
        
        # Create the replacement
        replacement = f"""# Create timeout callback function
        var {var_name} = func():
            {lambda_body}
        
        timeout.connect({var_name})"""
        
        return replacement
    
    # Apply the timeout fix
    fixed_content = re.sub(timeout_pattern, replace_timeout_lambda, fixed_content)
    
    # Fix any other .connect(lambda) patterns
    connect_pattern = r'\.connect\(func\(\):\s*([^}]+)\)'
    
    def replace_connect_lambda(match):
        lambda_body = match.group(1).strip()
        
        # Generate a unique variable name
        import uuid
        var_name = f"connect_callback_{str(uuid.uuid4())[:8]}"
        
        # Create the replacement
        replacement = f"""# Create connect callback function
        var {var_name} = func():
            {lambda_body}
        
        .connect({var_name})"""
        
        return replacement
    
    # Apply the connect fix
    fixed_content = re.sub(connect_pattern, replace_connect_lambda, fixed_content)
    
    # Write the fixed content back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(fixed_content)
    
    print(f"Fixed ALL lambda errors in {file_path}")

if __name__ == "__main__":
    fix_all_lambda_errors("combat_manager.gd")
    print("All lambda errors fixed!")
