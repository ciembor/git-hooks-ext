Name: git-hooks-ext
Version: 0.3.0
Release: 1%{?dist}
Summary: Semantic Git hooks for reference changes
License: GPL-2.0-only
URL: https://github.com/ciembor/git-hooks-ext
Source0: %{url}/releases/download/v%{version}/%{name}-%{version}.tar.gz
BuildRequires: gcc
BuildRequires: make
BuildRequires: git
Requires: git >= 2.29

%description
Turns reference-transaction input into branch, tag and other ref events.

%prep
%setup -q -c -T
tar -xzf %{SOURCE0}

%build
%make_build CFLAGS="%{build_cflags} -std=c99" LDFLAGS="%{build_ldflags}"

%check
make test

%install
make install PREFIX=%{_prefix} DESTDIR=%{buildroot}

%files
%license LICENSE COPYRIGHT
%doc README.md
%{_bindir}/git-hooks-ext
