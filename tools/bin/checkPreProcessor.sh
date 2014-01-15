find . \( \( -name "*.[chm]" -o -name "*.mm" \) -o -name "*.cpp" \) -print0 | xargs -0 egrep -n '^\w*\#' | egrep -v '(import|pragma|else|endif|HC_SHORTHAND)'


