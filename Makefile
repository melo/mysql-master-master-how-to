CSS_SRC=css/reset.css css/fonts.css css/base.css css/extra.css

all: how-to.html

preview: all
	open how-to.html

how-to.html: how-to.markdown css/multimarkdown.css
	MultiMarkdown.pl how-to.markdown > $@

css/multimarkdown.css: $(CSS_SRC)
	cat $(CSS_SRC) > $@
