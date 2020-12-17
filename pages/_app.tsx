import App from 'next/app';
import { createGlobalStyle } from 'styled-components';
import { Reset } from 'styled-reset';
import { createMuiTheme, ThemeProvider } from '@material-ui/core/styles';
import pink from '@material-ui/core/colors/pink';

const GlobalStyle = createGlobalStyle`
  html, body {
    height: 100%;
    background-color: #000;
    background-image: radial-gradient(at center bottom, rgba(230, 30, 99, 0.73) 0%, rgba(29, 38, 53, 0) 69%);
    color: #c9d1d9;
  }
  #__next {
    height: 100%;
  }
  * {
    box-sizing: border-box;
  }
`;

const theme = createMuiTheme({
  palette: {
    type: 'dark',
    primary: {
      main: pink[500]
    }
  }
});

export default class extends App {
  render() {
    const { Component, pageProps } = this.props;
    return (
      <>
        <Reset />
        <GlobalStyle />
        <ThemeProvider theme={theme}>
          <Component {...pageProps} />
        </ThemeProvider>
      </>
    );
  }
}
