module.exports = {
  stylesheet: ['style.css'],
  body_class: [],
  css: '',
  document_title: 'Database Ontwerp Voorstel',
  pdf_options: {
    format: 'A4',
    margin: {
      top: '25mm',
      right: '20mm',
      bottom: '25mm',
      left: '20mm'
    },
    printBackground: true
  },
  launch_options: {
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  },
  mermaid_options: {
    theme: 'default',
    themeVariables: {
      primaryColor: '#EDF8FD',
      primaryTextColor: '#222A54',
      primaryBorderColor: '#1A407E',
      lineColor: '#0098D5',
      secondaryColor: '#8ED2F2',
      tertiaryColor: '#EDF8FD'
    }
  }
};
