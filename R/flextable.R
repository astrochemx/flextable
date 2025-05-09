#' @title flextable creation
#'
#' @description Create a flextable object with function `flextable`.
#'
#' `flextable` are designed to make tabular reporting easier for
#' R users. Functions are available to let you format text, paragraphs and cells;
#' table cells can be merge vertically or horizontally, row headers can easily
#' be defined, rows heights and columns widths can be manually set or automatically
#' computed.
#'
#' If working with 'R Markdown' documents, you should read about knitr
#' chunk options in [knit_print.flextable()] and about setting
#' default values with [set_flextable_defaults()].
#'
#' @section Reuse frequently used parameters:
#'
#' Some default formatting properties are automatically
#' applied to every flextable you produce.
#'
#' It is highly recommended to use this function because
#' its use will minimize the code. For example, instead of
#' calling the `fontsize()` function over and over again for
#' each new flextable, set the font size default value by
#' calling (before creating the flextables)
#' `set_flextable_defaults(font.size = 11)`. This is also
#' a simple way to have homogeneous arrays and make the
#' documents containing them easier to read.
#'
#' You can change these default values with function
#' [set_flextable_defaults()]. You can reset them
#' with function [init_flextable_defaults()]. You
#' can access these values by calling [get_flextable_defaults()].
#'
#' @section new lines and tabulations:
#'
#' The 'flextable' package will translate for you
#' the new lines expressed in the form `\n` and
#' the tabs expressed in the form `\t`.
#'
#' The new lines will be transformed into "soft-return",
#' that is to say a simple carriage return and not a
#' new paragraph.
#'
#' Tabs are different depending on the output format:
#'
#' - HTML is using entity *em space*
#' - Word - a Word 'tab' element
#' - PowerPoint - a PowerPoint 'tab' element
#' - latex - tag "\\quad "
#' @section flextable parts:
#'
#' A `flextable` is made of 3 parts: header, body and footer.
#'
#' Most functions have an argument named `part` that will be used
#' to specify what part of of the table should be modified.
#' @param data dataset
#' @param col_keys columns names/keys to display. If some column names are not in
#' the dataset, they will be added as blank columns by default.
#' @param cwidth,cheight initial width and height to use for cell sizes in inches.
#' @param defaults,theme_fun deprecated, use [set_flextable_defaults()] instead.
#' @param use_labels Logical; if TRUE, any column labels or value labels
#' present in the dataset will be used for display purposes. Defaults
#' to TRUE.
#' @examples
#' ft <- flextable(head(mtcars))
#' ft
#' @export
#' @importFrom stats setNames
#' @seealso [style()], [autofit()], [theme_booktabs()], [knit_print.flextable()],
#' [compose()], [footnote()], [set_caption()]
flextable <- function(data, col_keys = names(data),
                      cwidth = .75, cheight = .25,
                      defaults = list(), theme_fun = theme_booktabs,
                      use_labels = TRUE) {
  stopifnot(is.data.frame(data), ncol(data) > 0)
  if (any(duplicated(col_keys))) {
    stop(sprintf(
      "duplicated col_keys: %s",
      paste0(unique(col_keys[duplicated(col_keys)]), collapse = ", ")
    ))
  }
  list_lbls <- collect_labels(dataset = data, use_labels = use_labels)

  if (inherits(data, "data.table") || inherits(data, "tbl_df") || inherits(data, "tbl")) {
    data <- as.data.frame(data, stringsAsFactors = FALSE)
  }

  blanks <- setdiff(col_keys, names(data))
  if (length(blanks) > 0) {
    blanks_col <- lapply(blanks, function(x, n) character(n), nrow(data))
    blanks_col <- setNames(blanks_col, blanks)
    data[blanks] <- blanks_col
  }

  body <- complex_tabpart(data = data, col_keys = col_keys, cwidth = cwidth, cheight = cheight)

  # header
  header_data <- setNames(as.list(col_keys), col_keys)
  header_data[blanks] <- as.list(rep("", length(blanks)))
  header_data <- as.data.frame(header_data, stringsAsFactors = FALSE, check.names = FALSE)

  header <- complex_tabpart(data = header_data, col_keys = col_keys, cwidth = cwidth, cheight = cheight)

  # footer
  footer_data <- header_data[FALSE, , drop = FALSE]
  footer <- complex_tabpart(data = footer_data, col_keys = col_keys, cwidth = cwidth, cheight = cheight)

  out <- list(
    header = header,
    body = body,
    footer = footer,
    col_keys = col_keys,
    caption = list(value = NULL),
    blanks = blanks
  )
  class(out) <- c("flextable")

  out <- do.call(flextable_global$defaults$theme_fun, list(out))
  out <- set_table_properties(x = out, layout = flextable_global$defaults$table.layout)

  if (length(list_lbls$variables_labels) > 0) {
    out <- labelizor(out, labels = unlist(list_lbls$variables_labels), part = "header")
  }

  apply_labels(out, collected_labels = list_lbls)
}

#' @export
#' @rdname flextable
#' @section qflextable:
#' `qflextable` is a convenient tool to produce quickly
#' a flextable for reporting where layout is fixed (see
#' [set_table_properties()]) and columns
#' widths are adjusted with [autofit()].
qflextable <- function(data) {
  ft <- flextable(data)
  ft <- set_table_properties(ft, layout = "fixed")
  autofit(ft)
}

#' @export
#' @title Set Caption
#' @description Set caption value in a flextable. The function
#' can also be used to define formattings that will be applied
#' if possible to Word and HTML outputs.
#'
#' * The caption will be associated with a paragraph style when
#' the output is Word. It can also be numbered as a auto-numbered
#' Word computed value.
#' * The PowerPoint format ignores captions. PowerPoint documents are not
#' structured and do not behave as HTML documents and paginated documents
#' (word, pdf), and it's not possible to know where we should create
#' a shape to contain the caption (technically it can't be in the
#' PowerPoint shape containing the table).
#'
#' When working with 'R Markdown' or 'Quarto', the caption settings
#' defined with `set_caption()` will be prioritized over knitr chunk options.
#'
#' Caption value can be a single string or the result to a call to
#' [as_paragraph()]. With the latter, the caption is made of
#' formatted chunks whereas with the former, caption will not be
#' associated with any formatting.
#'
#' @details
#' The behavior of captions in the 'flextable' package varies depending on the formats
#' and technologies used.
#'
#' The values set by the `set_caption()` function will be prioritized whenever
#' possible, including the caption ID and associated paragraph style.
#' However, it's important to note that the behavior may differ across different tools.
#' Here's what we have observed and attempted to respect, but please inform us
#' if you believe our observations are incorrect:
#'
#' - In Word and HTML documents created with 'rmarkdown' `rmarkdown::word_document()`
#' and `rmarkdown::html_document()`, numbered and cross-referenced captions are not
#' typically expected.
#' - In PDF documents created with 'rmarkdown' `rmarkdown::pdf_document()`, numbers
#' are automatically added before the caption.
#' - In Word and HTML documents created with 'bookdown', numbered and cross-referenced
#' captions are expected. 'bookdown' handles this functionality, but due to
#' technical reasons, the caption should not be defined within an HTML or XML block.
#' Therefore, when using 'flextable', the ability to format the caption content is
#' lost (this limitation does not apply to PDF documents).
#' - HTML and PDF documents created with Quarto handle captions and
#' cross-references differently. Quarto replaces captions with 'tbl-cap' and 'label'
#' values.
#' - Word documents created with Quarto present another specific case.
#' Currently, Quarto does not inject captions using the 'tbl-cap' and label values.
#' However, this is a temporary situation that is expected to change in the future.
#' The 'flextable' package will adapt accordingly as Quarto evolves.
#' - When using the `body_add_flextable()` function, all the options
#' specified with `set_caption()` will be enabled.
#'
#' Using [body_add_flextable()] enable all options specified with `set_caption()`.
#'
#' @section R Markdown:
#'
#' flextable captions can be defined from R Markdown documents by using
#' `knitr::opts_chunk$set()`. User don't always have to call `set_caption()`
#' to set a caption, he can use knitr chunk options instead. A typical call
#' would be:
#'
#' ``````
#' ```{r}
#' #| tab.id: bookmark_id
#' #| tab.cap: caption text
#' flextable(head(cars))
#' ```
#' ``````
#'
#' `tab.id` is the caption id or bookmark, `tab.cap` is the caption
#' text. There are many options that can replace `set_caption()`
#' features. The following knitr chunk options are available:
#'
#' | **label**                                               |    **name**     | **value**  |
#' |:--------------------------------------------------------|:---------------:|:----------:|
#' | Word stylename to use for table captions.               | tab.cap.style   |    NULL    |
#' | caption id/bookmark                                     | tab.id          |    NULL    |
#' | caption                                                 | tab.cap         |    NULL    |
#' | display table caption on top of the table or not        | tab.topcaption  |    TRUE    |
#' | caption table sequence identifier.                      | tab.lp          |   "tab:"   |
#' | prefix for numbering chunk (default to   "Table ").     | tab.cap.pre     |   Table    |
#' | suffix for numbering chunk (default to   ": ").         | tab.cap.sep     |    " :"    |
#' | title number depth                                      | tab.cap.tnd     |      0     |
#' | separator to use between title number and table number. | tab.cap.tns     |     "-"    |
#' | caption prefix formatting properties                    | tab.cap.fp_text | fp_text_lite(bold = TRUE) |
#'
#'
#' See [knit_print.flextable] for more details.
#'
#' @section Formatting the caption:
#'
#' To create captions in R Markdown using the 'flextable' package and 'officer'
#' package, you can utilize the `as_paragraph()` function. This approach is
#' recommended when your captions require complex content, such as a combination of
#' different text styles or the inclusion of images and equations.
#'
#' The caption is constructed as a paragraph consisting of multiple chunks. Each
#' chunk represents a specific portion of the caption with its desired formatting,
#' such as red bold text or Arial italic text.
#'
#' By default, if no specific formatting is specified (using either "a string" or
#' `as_chunk("a string")`), the `fp_text_default()` function sets the font settings
#' for the caption, including the font family, boldness, italics, color, etc. The
#' default values can be modified using the `set_flextable_defaults()` function.
#' However, it is recommended to explicitly use `as_chunk()` to define the desired
#' formatting.
#'
#' It's important to note that the style properties of the caption will not
#' override the formatting of the individual elements within it. Therefore, you
#' need to explicitly specify the font to be used for the caption.
#'
#' Here's an example of how to set a caption for a flextable in R Markdown using
#' the 'officer' package:
#'
#'
#' ```
#' library(flextable)
#' library(officer)
#'
#' ftab <- flextable(head(cars)) %>%
#'   set_caption(
#'     as_paragraph(
#'       as_chunk("caption", props = fp_text_default(font.family = "Cambria"))
#'     ), word_stylename = "Table Caption"
#'   )
#'
#' print(ftab, preview = "docx")
#' ```
#'
#' In this example, the `set_caption()` function sets the caption for the
#' flextable. The caption is created using `as_paragraph()` with a single chunk
#' created using `as_chunk("caption", props = fp_text_default(font.family =
#' "Cambria"))`. The `word_stylename` parameter is used to specify the table
#' caption style in the resulting Word document. Finally, the `print()` function
#' generates the flextable with the caption, and `preview = "docx"` displays a
#' preview of the resulting Word document.
#'
#' @section Using 'Quarto':
#'
#' In 'Quarto', captions and cross-references are handled differently
#' compared to 'R Markdown', where flextable takes care of the job.
#' In Quarto, the responsibility for managing captions lies with the Quarto
#' framework itself. Consequently, the `set_caption()` function in 'flextable'
#' is not as useful in a 'Quarto' document. The formatting and numbering of
#' captions are determined by Quarto rather than flextable. Please refer to
#' the Quarto documentation for more information on how to work with captions
#' in Quarto.
#'
#' @param x flextable object
#' @param caption caption value. The caption can be either a string either
#' a call to [as_paragraph()]. In the latter case, users are free to format
#' the caption with colors, italic fonts, also mixed with images or
#' equations. Note that Quarto does not allow the use of this feature.
#'
#' Caption as a string does not support 'Markdown' syntax. If you want to
#' add a bold text in the caption, use `as_paragraph('a ', as_b('bold'), ' text')`
#' when providing caption.
#' @param autonum an autonum representation. See [officer::run_autonum()].
#' This has an effect only when the output is "Word" (in which case the object
#' is used to define the Word auto-numbering), "html" and "pdf" (in which case only
#' the bookmark identifier will be used). If used, the caption is preceded
#' by an auto-number sequence.
#' @param word_stylename,style 'Word' style name to associate with caption paragraph. These names are available with
#' function [officer::styles_info()] when output is Word. Argument `style`
#' is deprecated in favor of `word_stylename`. If the caption is defined with
#' `as_paragraph()`, some of the formattings of the paragraph style will be
#' replaced by the formattings associated with the chunks (such as the font).
#' @param fp_p paragraph formatting properties associated with the caption, see [officer::fp_par()].
#' It applies when possible, i.e. in HTML and 'Word' but not with bookdown.
#' @param align_with_table if TRUE, caption is aligned as the flextable, if FALSE,
#' `fp_p` will not be updated and alignement is as defined with `fp_p`.
#' It applies when possible, i.e. in HTML and 'Word' but not with bookdown.
#' @param html_classes css class(es) to apply to associate with caption paragraph
#' when output is 'Word'.
#' @param html_escape should HTML entities be escaped so that it can be safely
#' included as text or an attribute value within an HTML document.
#' @examples
#' ftab <- flextable(head(iris))
#' ftab <- set_caption(ftab, "my caption")
#' ftab
#'
#' library(officer)
#' autonum <- run_autonum(seq_id = "tab", bkm = "mtcars")
#' ftab <- flextable(head(mtcars))
#' ftab <- set_caption(ftab, caption = "mtcars data", autonum = autonum)
#' ftab
#' @importFrom officer run_autonum
#' @importFrom htmltools htmlEscape
#' @seealso [flextable()]
set_caption <- function(x,
                        caption = NULL,
                        autonum = NULL,
                        word_stylename = "Table Caption",
                        style = word_stylename,
                        fp_p = fp_par(padding = 3),
                        align_with_table = TRUE,
                        html_classes = NULL,
                        html_escape = TRUE) {
  if (!inherits(x, "flextable")) {
    stop(sprintf("Function `%s` supports only flextable objects.", "set_caption()"))
  }

  caption_value <- NULL
  simple_caption <- TRUE
  if (!is.null(caption) && !inherits(caption, "paragraph")) {
    caption_value <- caption
  } else if (!is.null(caption) && inherits(caption, "paragraph")) {
    simple_caption <- FALSE
    caption_value <- caption[[1]]

    by_columns <- c(
      "font.size", "italic", "bold", "underlined", "color", "shading.color",
      "font.family", "hansi.family", "eastasia.family", "cs.family",
      "vertical.align"
    )
    default_fp_t <- fp_text_default()
    for (j in by_columns) {
      caption_value[[j]][is.na(caption_value[[j]])] <- default_fp_t[[j]]
    }
  }
  if (!is.null(caption) && !simple_caption) {
    caption_value <- expand_special_char(caption_value, what = "\n", with = "<br>")
    caption_value <- expand_special_char(caption_value, what = "\t", with = "<tab>")
  }

  x$caption <- list(
    value = caption_value,
    simple_caption = simple_caption,
    align_with_table = align_with_table
  )

  if (!is.null(autonum) && inherits(autonum, "run_autonum")) {
    x$caption$autonum <- autonum
  }
  x$caption$fp_p <- fp_p
  x$caption$style <- style
  x$caption$word_stylename <- word_stylename
  x$caption$html_classes <- if (!is.null(html_classes)) paste(html_classes, collapse = " ") else NULL

  x
}
update_caption <- function(x, caption = NULL,
                           autonum = NULL,
                           word_stylename = NULL,
                           fp_p = NULL,
                           align_with_table = NULL,
                           html_classes = NULL) {
  if (!is.null(caption)) {
    if (inherits(caption, "paragraph")) {
      x$caption$simple_caption <- FALSE
    } else {
      x$caption$simple_caption <- TRUE
    }
    x$caption$value <- caption
  }

  if (!is.null(autonum)) {
    x$caption$autonum <- autonum
  }

  if (!is.null(fp_p)) {
    x$caption$fp_p <- fp_p
  }

  if (!is.null(word_stylename)) {
    x$caption$word_stylename <- word_stylename
  }
  if (!is.null(html_classes)) {
    x$caption$html_classes <- html_classes
  }
  if (!is.null(align_with_table)) {
    x$caption$align_with_table <- align_with_table
  }

  x
}


#' @keywords internal
#' @title flextable old functions
#' @description The function is maintained for compatibility with old codes
#' mades by users but be aware it produces the same exact object than [flextable()].
#' This function should be deprecated then removed in the next versions.
#' @param data dataset
#' @param col_keys columns names/keys to display. If some column names are not in
#' the dataset, they will be added as blank columns by default.
#' @param cwidth,cheight initial width and height to use for cell sizes in inches.
#' @export
regulartable <- function(data, col_keys = names(data), cwidth = .75, cheight = .25) {
  flextable(data = data, col_keys = col_keys, cwidth = cwidth, cheight = cheight)
}

#' @importFrom officer table_layout table_width table_colwidths prop_table
#' @export
#' @title Global table properties
#' @description Set table layout and table width. Default to fixed
#' algorithm.
#'
#' If layout is fixed, column widths will be used to display the table;
#' `width` is ignored.
#'
#' If layout is autofit, column widths will not be used;
#' table width is used (as a percentage).
#' @note
#' PowerPoint output ignore 'autofit layout'.
#' @param x flextable object
#' @param layout 'autofit' or 'fixed' algorithm. Default to 'fixed'.
#' @param width The parameter has a different effect depending on the
#' output format. Users should consider it as a minimum width.
#' In HTML, it is the minimum width of the space that the
#' table should occupy. In Word, it is a preferred size and Word
#' may decide not to strictly stick to it. It has no effect on
#' PowerPoint and PDF output. Its default value is 0, as an effect, it
#' only use necessary width to display all content. It is not used by the
#' PDF output.
#' @param align alignment in document (only Word, HTML and PDF),
#' supported values are 'left', 'center' and 'right'.
#' @param opts_html html options as a list. Supported elements are:
#' - 'extra_css': extra css instructions to be integrated with the HTML
#' code of the table.
#' - 'scroll': NULL or a list if you want to add a scroll-box.
#'     - Use an empty list to add an horizontal scroll.  The with
#'     is fixed, corresponding to the container's width.
#'     - If the list has a value named `height` it will be used as
#'     height and the scroll will happen also vertically. The height
#'     will be in pixel if numeric, if a string it should be a valid css
#'     measure.
#'     - If the list has a value named `freeze_first_column` set to `TRUE`,
#'     the first column is set as a *sticky* column.
#'     - If the list has a value named `add_css` it will be used as extra
#'     css to add, .i.e: `border:1px solid red;`.
#' - 'extra_class': extra classes to add in the table tag
#' @param opts_word Word options as a list. Supported elements are:
#' - 'split':  Word option 'Allow row to break across pages' can be
#' activated when TRUE.
#' - 'keep_with_next': Word option 'keep rows together' is
#' activated when TRUE. It avoids page break within tables. This
#' is handy for small tables, i.e. less than a page height.
#' @param opts_pdf PDF options as a list. Supported elements are:
#' - 'tabcolsep': space between the text and the left/right border of its containing
#' cell.
#' - 'arraystretch': height of each row relative to its default
#' height, the default value is 1.5.
#' - 'float': type of floating placement in the PDF document, one of:
#'     * 'none' (the default value), table is placed after the preceding
#' paragraph.
#'     * 'float', table can float to a place in the text where it fits best
#'     * 'wrap-r', wrap text around the table positioned to the right side of the text
#'     * 'wrap-l', wrap text around the table positioned to the left side of the text
#'     * 'wrap-i', wrap text around the table positioned inside edge-near the binding
#'     * 'wrap-o', wrap text around the table positioned outside edge-far from the binding
#' - 'fonts_ignore': if TRUE, pdf-engine 'pdflatex' can be used instead of
#' 'xelatex' or 'lualatex.' If pdflatex is used, fonts will be ignored because they are
#' not supported by pdflatex, whereas with the xelatex and lualatex engines they are.
#' - 'caption_repeat': a boolean that indicates if the caption should be
#' repeated along pages. Its default value is `TRUE`.
#' - 'footer_repeat': a boolean that indicates if the footer should be
#' repeated along pages. Its default value is `TRUE`.
#' - 'default_line_color': default line color, restored globally after
#' the flextable is produced.
#' @param word_title alternative text for Word table (used as title of the table)
#' @param word_description alternative text for Word table (used as description of the table)
#' @examples
#' library(flextable)
#' ft_1 <- flextable(head(cars))
#' ft_1 <- autofit(ft_1)
#' ft_2 <- set_table_properties(ft_1, width = .5, layout = "autofit")
#' ft_2
#' ft_3 <- set_table_properties(ft_1, width = 1, layout = "autofit")
#'
#' # add scroll for HTML ----
#' set.seed(2)
#' dat <- lapply(1:14, function(x) rnorm(n = 20))
#' dat <- setNames(dat, paste0("colname", 1:14))
#' dat <- as.data.frame(dat)
#'
#' ft_4 <- flextable(dat)
#' ft_4 <- colformat_double(ft_4)
#' ft_4 <- bg(ft_4, j = 1, bg = "#DDDDDD", part = "all")
#' ft_4 <- bg(ft_4, i = 1, bg = "#DDDDDD", part = "header")
#' ft_4 <- autofit(ft_4)
#' ft_4 <- set_table_properties(
#'   x = ft_4,
#'   opts_html = list(
#'     scroll = list(
#'       height = "500px",
#'       freeze_first_column = TRUE
#'     )
#'   )
#' )
#' ft_4
#' @family flextable dimensions
set_table_properties <- function(x, layout = "fixed", width = 0,
                                 align = NULL,
                                 opts_html = list(),
                                 opts_word = list(),
                                 opts_pdf = list(),
                                 word_title = NULL, word_description = NULL) {
  stopifnot(
    `wrong layout value` = layout %in% c("fixed", "autofit"),
    `width is not numeric` = is.numeric(width),
    `width is > 1` = width <= 1
  )

  if (!is.null(word_title)) {
    stopifnot(
      is.character(word_title),
      length(word_title) == 1
    )
    stopifnot(
      is.character(word_description),
      length(word_description) == 1
    )
  }

  x$properties <- list(
    layout = layout,
    width = width,
    align = if (is.null(align)) get_flextable_defaults()$table_align else align,
    opts_html = do.call(opts_ft_html, opts_html),
    opts_word = do.call(opts_ft_word, opts_word),
    opts_pdf = do.call(opts_ft_pdf, opts_pdf),
    word_title = word_title,
    word_description = word_description
  )
  x
}

opts_ft_html <- function(extra_css = get_flextable_defaults()$extra_css,
                         scroll = get_flextable_defaults()$scroll,
                         extra_class = NULL,
                         ...) {
  if (!is.character(extra_css) || length(extra_css) != 1 || any(is.na(extra_css))) {
    stop(sprintf("'%s' is expected to be a single %s.", "extra_css", "character"), call. = FALSE)
  }
  if (!is.null(scroll) && !is.list(scroll)) {
    stop(sprintf("'%s' is expected to be %s.", "scroll", "NULL or a list"), call. = FALSE)
  }

  z <- list(extra_css = extra_css, scroll = scroll, extra_class = extra_class)
  class(z) <- "opts_ft_html"
  z
}
opts_ft_word <- function(split = get_flextable_defaults()$split, keep_with_next = get_flextable_defaults()$keep_with_next) {
  if (!is.logical(split) || length(split) != 1) {
    stop(sprintf("'%s' is expected to be a single %s.", "split", "logical"), call. = FALSE)
  }
  if (!is.logical(keep_with_next) || length(keep_with_next) != 1) {
    stop(sprintf("'%s' is expected to be a single %s.", "keep_with_next", "logical"), call. = FALSE)
  }

  z <- list(split = split, keep_with_next = keep_with_next)
  class(z) <- "opts_ft_word"
  z
}
opts_ft_pdf <- function(tabcolsep = get_flextable_defaults()$tabcolsep,
                        arraystretch = get_flextable_defaults()$arraystretch,
                        float = get_flextable_defaults()$float,
                        fonts_ignore = get_flextable_defaults()$fonts_ignore,
                        caption_repeat = TRUE,
                        footer_repeat = FALSE,
                        default_line_color = "black") {
  if (!is.logical(fonts_ignore) || length(fonts_ignore) != 1) {
    stop(sprintf("'%s' is expected to be a single %s.", "fonts_ignore", "logical"), call. = FALSE)
  }
  if (!is.numeric(tabcolsep) || length(tabcolsep) != 1 || any(sign(tabcolsep) < 0)) {
    stop(sprintf("'%s' is expected to be a single %s.", "tabcolsep", "positive number"), call. = FALSE)
  }
  if (!is.numeric(arraystretch) || length(arraystretch) != 1 || any(sign(arraystretch) < 0)) {
    stop(sprintf("'%s' is expected to be a single %s.", "arraystretch", "positive number"), call. = FALSE)
  }
  if (!is.character(float) || length(float) != 1 || !all(float %in% c("none", "float", "wrap-r", "wrap-l", "wrap-i", "wrap-o"))) {
    stop(sprintf("'%s' is expected to be a single %s.", "float", "character (one of 'none', 'float', 'wrap-r', 'wrap-l', 'wrap-i', 'wrap-o')"), call. = FALSE)
  }
  if (!is.logical(caption_repeat) || length(caption_repeat) != 1) {
    stop(sprintf("'%s' is expected to be a single %s.", "logical"), call. = FALSE)
  }

  z <- list(
    tabcolsep = tabcolsep,
    arraystretch = arraystretch,
    float = float,
    default_line_color = default_line_color,
    caption_repeat = caption_repeat,
    footer_repeat = footer_repeat,
    fonts_ignore = fonts_ignore
  )
  class(z) <- "opts_ft_pdf"
  z
}


#' @export
knit_print.run_reference <- function(x, ...) {
  is_quarto <- is_in_quarto()
  title <- ""
  if (is_quarto) {
    title <- opts_current_table()$cap.pre
  }
  if (grepl("docx", opts_knit$get("rmarkdown.pandoc.to"))) {
    knit_print(asis_output(
      paste(title, "`", to_wml(x), "`{=openxml}", sep = "")
    ))
  } else if (is_quarto) {
    knit_print(asis_output(
      paste("@", x$id, sep = "")
    ))
  } else {
    knit_print(asis_output(
      paste("\\@ref(tab:", x$id, ")", sep = "")
    ))
  }
}
