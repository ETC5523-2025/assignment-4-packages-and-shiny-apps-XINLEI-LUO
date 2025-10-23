library(shiny)
library(assignment4.xinlei.luo)
library(ggplot2)

ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "yeti"),
  titlePanel("Germany HAI Burden Explorer"),
  sidebarLayout(
    sidebarPanel(
      selectInput("dataset", "Choose dataset", choices = list_hai_datasets()),
      selectInput("metric", "Metric", choices = c("cases","deaths","daly")),
      selectInput("group", "Group by", choices = c("infection_type","sample"))
    ),
    mainPanel(
      tags$h4("How to interpret"),
      tags$p(HTML(
        "<b style='color:steelblue;'>cases</b>: number of HAI infections<br/>
   <b style='color:firebrick;'>deaths</b>: number of deaths attributable to HAI<br/>
   <b style='color:darkgreen;'>daly</b>: disability-adjusted life years (YLL + YLD)"
      )),
      plotOutput("p")
    )
  )
)

server <- function(input, output, session){
  dat <- reactive(read_hai_dataset(input$dataset))
  output$p <- renderPlot({
    smry <- summarise_hai(dat(), by = input$group, metric = input$metric)
    ggplot(smry, aes(group, value, fill = group)) +
      geom_col() +
      labs(x = NULL, y = input$metric) +
      scale_fill_brewer(palette = "Set2") +
      theme_minimal(base_size = 14) +
      theme(
        legend.position = "none",
        axis.text.x = element_text(color = "black", face = "bold"),
        axis.title.y = element_text(color = "darkblue", face = "bold")
      )
  })
}

shinyApp(ui, server)
