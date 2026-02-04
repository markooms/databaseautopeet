#!/usr/bin/env python3
"""
HAR Parser - Extract API endpoints from browser HAR files

Usage:
    python parse_har.py <har_file> [--output skills/portal_name]

Captures:
    - API endpoints (XHR/Fetch requests)
    - Authentication headers (Cookie, Authorization, etc.)
    - Request/response patterns
    - Generates reusable Python code
"""

import json
import sys
import os
import re
from urllib.parse import urlparse, parse_qs
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from collections import defaultdict


@dataclass
class AuthInfo:
    """Captured authentication information"""
    cookies: Dict[str, str]
    bearer_token: Optional[str]
    api_key: Optional[str]
    csrf_token: Optional[str]
    custom_headers: Dict[str, str]
    
    def to_headers(self) -> Dict[str, str]:
        """Convert to requests-compatible headers dict"""
        headers = {}
        
        if self.cookies:
            headers["Cookie"] = "; ".join(f"{k}={v}" for k, v in self.cookies.items())
        
        if self.bearer_token:
            headers["Authorization"] = f"Bearer {self.bearer_token}"
        elif self.api_key:
            headers["Authorization"] = self.api_key
            
        if self.csrf_token:
            headers["X-CSRF-Token"] = self.csrf_token
            
        headers.update(self.custom_headers)
        
        return headers


@dataclass  
class APIEndpoint:
    """Represents a discovered API endpoint"""
    method: str
    url: str
    path: str
    query_params: Dict[str, List[str]]
    request_headers: Dict[str, str]
    request_body: Optional[str]
    response_status: int
    response_content_type: str
    response_body_preview: Optional[str]
    response_size: int
    timing_ms: float
    
    
class HARParser:
    """Parse HAR files and extract API information"""
    
    # Headers that indicate authentication
    AUTH_HEADERS = [
        "authorization",
        "x-api-key", 
        "x-auth-token",
        "x-csrf-token",
        "x-xsrf-token",
        "x-access-token",
        "api-key",
        "bearer",
    ]
    
    # Content types that indicate API calls
    API_CONTENT_TYPES = [
        "application/json",
        "application/xml",
        "text/xml",
        "application/x-www-form-urlencoded",
    ]
    
    # Skip these resource types
    SKIP_TYPES = ["image", "font", "stylesheet", "script"]
    
    def __init__(self, har_path: str):
        self.har_path = har_path
        self.har_data = self._load_har()
        self.endpoints: List[APIEndpoint] = []
        self.auth_info: Optional[AuthInfo] = None
        self.base_url: Optional[str] = None
        
    def _load_har(self) -> dict:
        """Load and parse HAR file"""
        with open(self.har_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def parse(self) -> None:
        """Parse all entries in HAR file"""
        entries = self.har_data.get("log", {}).get("entries", [])
        
        print(f"📂 Parsing {len(entries)} requests from HAR file...")
        
        # First pass: collect all auth info
        all_auth = self._collect_auth_info(entries)
        self.auth_info = all_auth
        
        # Second pass: extract API endpoints
        for entry in entries:
            endpoint = self._parse_entry(entry)
            if endpoint:
                self.endpoints.append(endpoint)
                
        # Determine base URL from most common domain
        if self.endpoints:
            domains = defaultdict(int)
            for ep in self.endpoints:
                parsed = urlparse(ep.url)
                domains[f"{parsed.scheme}://{parsed.netloc}"] += 1
            self.base_url = max(domains, key=domains.get)
            
        print(f"✅ Found {len(self.endpoints)} API endpoints")
        print(f"🔗 Base URL: {self.base_url}")
        
    def _collect_auth_info(self, entries: List[dict]) -> AuthInfo:
        """Collect authentication info from all requests"""
        cookies = {}
        bearer_token = None
        api_key = None
        csrf_token = None
        custom_headers = {}
        
        for entry in entries:
            request = entry.get("request", {})
            headers = {h["name"].lower(): h["value"] for h in request.get("headers", [])}
            
            # Extract cookies
            for cookie in request.get("cookies", []):
                cookies[cookie["name"]] = cookie["value"]
            
            # Also parse Cookie header
            if "cookie" in headers:
                for part in headers["cookie"].split(";"):
                    if "=" in part:
                        k, v = part.strip().split("=", 1)
                        cookies[k] = v
            
            # Extract bearer token
            if "authorization" in headers:
                auth = headers["authorization"]
                if auth.lower().startswith("bearer "):
                    bearer_token = auth[7:]
                else:
                    api_key = auth
                    
            # Extract CSRF tokens
            for header_name in ["x-csrf-token", "x-xsrf-token"]:
                if header_name in headers:
                    csrf_token = headers[header_name]
                    
            # Extract other auth headers
            for header_name in self.AUTH_HEADERS:
                if header_name in headers and header_name not in ["authorization", "x-csrf-token", "x-xsrf-token"]:
                    custom_headers[header_name] = headers[header_name]
                    
        return AuthInfo(
            cookies=cookies,
            bearer_token=bearer_token,
            api_key=api_key,
            csrf_token=csrf_token,
            custom_headers=custom_headers
        )
    
    def _parse_entry(self, entry: dict) -> Optional[APIEndpoint]:
        """Parse a single HAR entry into an API endpoint"""
        request = entry.get("request", {})
        response = entry.get("response", {})
        
        method = request.get("method", "GET")
        url = request.get("url", "")
        
        # Skip non-API requests
        if not self._is_api_request(request, response):
            return None
            
        # Parse URL
        parsed = urlparse(url)
        path = parsed.path
        query_params = parse_qs(parsed.query)
        
        # Get request headers
        headers = {h["name"]: h["value"] for h in request.get("headers", [])}
        
        # Get request body
        post_data = request.get("postData", {})
        request_body = post_data.get("text") if post_data else None
        
        # Get response info
        status = response.get("status", 0)
        content = response.get("content", {})
        content_type = content.get("mimeType", "")
        response_body = content.get("text", "")
        response_size = content.get("size", 0)
        
        # Truncate response preview
        response_preview = None
        if response_body:
            response_preview = response_body[:500] + "..." if len(response_body) > 500 else response_body
            
        # Get timing
        timing = entry.get("time", 0)
        
        return APIEndpoint(
            method=method,
            url=url,
            path=path,
            query_params=query_params,
            request_headers=headers,
            request_body=request_body,
            response_status=status,
            response_content_type=content_type,
            response_body_preview=response_preview,
            response_size=response_size,
            timing_ms=timing
        )
    
    def _is_api_request(self, request: dict, response: dict) -> bool:
        """Determine if this is likely an API request"""
        url = request.get("url", "")
        
        # Skip data URLs
        if url.startswith("data:"):
            return False
            
        # Skip common static resources
        static_extensions = ['.js', '.css', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.woff', '.woff2', '.ttf', '.ico']
        if any(url.lower().endswith(ext) for ext in static_extensions):
            return False
            
        # Check response content type
        content = response.get("content", {})
        content_type = content.get("mimeType", "").lower()
        
        # Include JSON responses
        if "json" in content_type:
            return True
            
        # Include XML responses
        if "xml" in content_type:
            return True
            
        # Check for API-like paths
        api_patterns = ['/api/', '/v1/', '/v2/', '/graphql', '/rest/', '/_api/', '/ajax/']
        if any(pattern in url.lower() for pattern in api_patterns):
            return True
            
        # Check request headers for XHR indicators
        headers = {h["name"].lower(): h["value"] for h in request.get("headers", [])}
        if headers.get("x-requested-with") == "XMLHttpRequest":
            return True
            
        # Accept header indicates API
        accept = headers.get("accept", "")
        if "application/json" in accept:
            return True
            
        return False
    
    def get_summary(self) -> Dict[str, Any]:
        """Get a summary of parsed data"""
        methods = defaultdict(int)
        statuses = defaultdict(int)
        
        for ep in self.endpoints:
            methods[ep.method] += 1
            statuses[ep.response_status] += 1
            
        return {
            "total_endpoints": len(self.endpoints),
            "base_url": self.base_url,
            "methods": dict(methods),
            "status_codes": dict(statuses),
            "has_auth": bool(self.auth_info.bearer_token or self.auth_info.cookies or self.auth_info.api_key),
            "auth_type": self._get_auth_type()
        }
    
    def _get_auth_type(self) -> str:
        """Determine the primary auth type"""
        if self.auth_info.bearer_token:
            return "Bearer Token"
        elif self.auth_info.api_key:
            return "API Key"
        elif self.auth_info.cookies:
            return "Session Cookie"
        else:
            return "None"
    
    def generate_python_code(self) -> str:
        """Generate Python code to replay API calls"""
        code = '''#!/usr/bin/env python3
"""
Auto-generated API client from HAR capture
Generated: {timestamp}
Base URL: {base_url}
Auth Type: {auth_type}
"""

import requests
from typing import Optional, Dict, Any


class APIClient:
    """Auto-generated API client"""
    
    def __init__(self):
        self.base_url = "{base_url}"
        self.session = requests.Session()
        self._setup_auth()
    
    def _setup_auth(self):
        """Configure authentication headers"""
        {auth_setup}
    
{methods}

# Quick test
if __name__ == "__main__":
    client = APIClient()
    # Test the first GET endpoint
    # Uncomment and modify as needed:
{test_code}
'''
        
        # Generate auth setup code
        auth_lines = []
        if self.auth_info.cookies:
            cookies_str = json.dumps(self.auth_info.cookies, indent=12)
            auth_lines.append(f'self.session.cookies.update({cookies_str})')
        
        if self.auth_info.bearer_token:
            auth_lines.append(f'self.session.headers["Authorization"] = "Bearer {self.auth_info.bearer_token}"')
        elif self.auth_info.api_key:
            auth_lines.append(f'self.session.headers["Authorization"] = "{self.auth_info.api_key}"')
            
        if self.auth_info.csrf_token:
            auth_lines.append(f'self.session.headers["X-CSRF-Token"] = "{self.auth_info.csrf_token}"')
            
        for header, value in self.auth_info.custom_headers.items():
            auth_lines.append(f'self.session.headers["{header}"] = "{value}"')
            
        auth_setup = "\n        ".join(auth_lines) if auth_lines else "pass  # No auth detected"
        
        # Generate methods for each endpoint
        methods = []
        seen_paths = set()
        test_lines = []
        
        for ep in self.endpoints:
            # Skip duplicates
            key = f"{ep.method}:{ep.path}"
            if key in seen_paths:
                continue
            seen_paths.add(key)
            
            method_name = self._path_to_method_name(ep.method, ep.path)
            method_code = self._generate_method(ep, method_name)
            methods.append(method_code)
            
            # Add test for first GET
            if ep.method == "GET" and not test_lines:
                test_lines.append(f'    # result = client.{method_name}()')
                test_lines.append(f'    # print(result)')
        
        return code.format(
            timestamp=datetime.now().isoformat(),
            base_url=self.base_url or "https://example.com",
            auth_type=self._get_auth_type(),
            auth_setup=auth_setup,
            methods="\n".join(methods),
            test_code="\n".join(test_lines) if test_lines else "    pass"
        )
    
    def _path_to_method_name(self, method: str, path: str) -> str:
        """Convert path to a valid Python method name"""
        # Remove leading slash and query params
        clean = path.lstrip("/").split("?")[0]
        
        # Replace non-alphanumeric with underscore
        clean = re.sub(r'[^a-zA-Z0-9]', '_', clean)
        
        # Remove multiple underscores
        clean = re.sub(r'_+', '_', clean).strip('_')
        
        # Add method prefix
        prefix = method.lower()
        
        return f"{prefix}_{clean}" if clean else f"{prefix}_root"
    
    def _generate_method(self, ep: APIEndpoint, method_name: str) -> str:
        """Generate a method for an endpoint"""
        parsed = urlparse(ep.url)
        path = parsed.path
        
        params = []
        param_docs = []
        
        # Add query params as method params
        for param, values in ep.query_params.items():
            params.append(f'{param}: Optional[str] = "{values[0]}"')
            param_docs.append(f"        {param}: Query parameter")
        
        # Add body param for POST/PUT/PATCH
        if ep.method in ["POST", "PUT", "PATCH"] and ep.request_body:
            params.append("body: Optional[Dict[str, Any]] = None")
            param_docs.append("        body: Request body")
        
        params_str = ", ".join(["self"] + params) if params else "self"
        
        # Build the method
        method_code = f'''    def {method_name}({params_str}) -> Dict[str, Any]:
        """
        {ep.method} {path}
        
        Status: {ep.response_status}
        Response: {ep.response_content_type}
{chr(10).join(param_docs) if param_docs else ""}
        """
        url = f"{{self.base_url}}{path}"
        '''
        
        # Add query params
        if ep.query_params:
            method_code += f'''
        params = {{
            {", ".join(f'"{k}": {k}' for k in ep.query_params.keys())}
        }}
        '''
        else:
            method_code += "\n        params = {}\n        "
        
        # Add request body
        if ep.method in ["POST", "PUT", "PATCH"]:
            method_code += f'''
        response = self.session.{ep.method.lower()}(url, params=params, json=body)
        '''
        else:
            method_code += f'''
        response = self.session.{ep.method.lower()}(url, params=params)
        '''
        
        method_code += '''
        response.raise_for_status()
        return response.json() if response.content else {}
'''
        
        return method_code
    
    def save_skill(self, output_dir: str) -> None:
        """Save as a reusable skill folder"""
        os.makedirs(output_dir, exist_ok=True)
        
        # Save Python client
        client_path = os.path.join(output_dir, "client.py")
        with open(client_path, 'w') as f:
            f.write(self.generate_python_code())
        print(f"📄 Saved client: {client_path}")
        
        # Save auth info (encrypted in real version)
        auth_path = os.path.join(output_dir, "auth.json")
        with open(auth_path, 'w') as f:
            json.dump({
                "cookies": self.auth_info.cookies,
                "bearer_token": self.auth_info.bearer_token,
                "api_key": self.auth_info.api_key,
                "csrf_token": self.auth_info.csrf_token,
                "custom_headers": self.auth_info.custom_headers,
                "base_url": self.base_url,
                "captured_at": datetime.now().isoformat()
            }, f, indent=2)
        print(f"🔐 Saved auth: {auth_path}")
        
        # Save endpoints summary
        endpoints_path = os.path.join(output_dir, "endpoints.json")
        with open(endpoints_path, 'w') as f:
            json.dump([{
                "method": ep.method,
                "path": ep.path,
                "query_params": ep.query_params,
                "response_status": ep.response_status,
                "response_content_type": ep.response_content_type,
                "timing_ms": ep.timing_ms
            } for ep in self.endpoints], f, indent=2)
        print(f"📋 Saved endpoints: {endpoints_path}")
        
        # Save SKILL.md
        skill_md = self._generate_skill_md()
        skill_path = os.path.join(output_dir, "SKILL.md")
        with open(skill_path, 'w') as f:
            f.write(skill_md)
        print(f"📖 Saved docs: {skill_path}")
        
    def _generate_skill_md(self) -> str:
        """Generate SKILL.md documentation"""
        summary = self.get_summary()
        
        md = f'''# API Skill: {urlparse(self.base_url).netloc if self.base_url else "Unknown"}

Auto-generated from HAR capture.

## Summary

- **Base URL:** {self.base_url}
- **Auth Type:** {summary["auth_type"]}
- **Total Endpoints:** {summary["total_endpoints"]}
- **Methods:** {", ".join(f"{k}: {v}" for k, v in summary["methods"].items())}

## Endpoints

| Method | Path | Status | Response Type |
|--------|------|--------|---------------|
'''
        
        for ep in self.endpoints:
            md += f"| {ep.method} | `{ep.path}` | {ep.response_status} | {ep.response_content_type} |\n"
        
        md += '''
## Usage

```python
from client import APIClient

client = APIClient()
# Call endpoints using generated methods
```

## Auth Notes

'''
        if self.auth_info.bearer_token:
            md += "- Uses **Bearer Token** authentication\n"
            md += "- Token may expire - refresh by re-capturing HAR\n"
        if self.auth_info.cookies:
            md += f"- Uses **Session Cookies** ({len(self.auth_info.cookies)} cookies)\n"
        if self.auth_info.csrf_token:
            md += "- Includes **CSRF Token** protection\n"
            
        return md


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_har.py <har_file> [--output <skill_dir>]")
        print("")
        print("Example:")
        print("  python parse_har.py portal.har --output skills/portal")
        sys.exit(1)
    
    har_path = sys.argv[1]
    output_dir = None
    
    # Parse --output flag
    if "--output" in sys.argv:
        idx = sys.argv.index("--output")
        if idx + 1 < len(sys.argv):
            output_dir = sys.argv[idx + 1]
    
    # Parse HAR
    parser = HARParser(har_path)
    parser.parse()
    
    # Print summary
    summary = parser.get_summary()
    print("\n" + "="*50)
    print("📊 SUMMARY")
    print("="*50)
    print(f"Base URL: {summary['base_url']}")
    print(f"Auth Type: {summary['auth_type']}")
    print(f"Total Endpoints: {summary['total_endpoints']}")
    print(f"Methods: {summary['methods']}")
    print(f"Status Codes: {summary['status_codes']}")
    
    # Show some endpoints
    print("\n📋 Sample Endpoints:")
    for ep in parser.endpoints[:10]:
        print(f"  {ep.method:6} {ep.path} → {ep.response_status}")
    if len(parser.endpoints) > 10:
        print(f"  ... and {len(parser.endpoints) - 10} more")
    
    # Save skill if output specified
    if output_dir:
        print(f"\n💾 Saving skill to: {output_dir}")
        parser.save_skill(output_dir)
    else:
        # Just print the generated code
        print("\n" + "="*50)
        print("🐍 GENERATED PYTHON CODE")
        print("="*50)
        print(parser.generate_python_code())
        print("\n💡 Tip: Use --output <dir> to save as reusable skill")


if __name__ == "__main__":
    main()
