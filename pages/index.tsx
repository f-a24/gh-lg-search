import * as React from 'react';
import { NextPage } from 'next';
import styled from 'styled-components';
import { load } from 'js-yaml';
import Button from '@material-ui/core/Button';
import CircularProgress from '@material-ui/core/CircularProgress';
import Dialog from '@material-ui/core/Dialog';
import TextField from '@material-ui/core/TextField';
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';

type PropsType = {
  allLang: {
    lang: string;
    type: string;
    color: string;
  }[];
};

type LanguageType = {
  name: string;
  value: number;
  color: string;
}[];

type UserDataType = {
  loading: boolean;
  avatar: string;
  bio: string;
  login: string;
  name: string;
  lang: LanguageType;
};

const App: NextPage<PropsType> = ({ allLang }) => {
  const [userName, setUserName] = React.useState('');
  const [userData, setUserData] = React.useState<UserDataType>({
    loading: false,
    avatar: '',
    bio: '',
    login: '',
    name: '',
    lang: []
  });

  const inputHandler = (e: React.ChangeEvent<HTMLInputElement>) => {
    setUserName(e.target.value);
  };
  const clickHandler = async () => {
    setUserData({ ...userData, loading: true });
    const langsArray: string[] = [];
    const userUrl = `https://api.github.com/users/${encodeURI(userName)}`;
    const userRes = await fetch(userUrl);
    const { avatar_url, bio, login, name, public_repos } = await userRes.json();
    const reposPage = public_repos / 100;

    for (let i = 0; i <= reposPage; i++) {
      const reposUrl = `https://api.github.com/users/${encodeURI(
        userName
      )}/repos?per_page=100&page=${i + 1}`;
      const reposRes = await fetch(reposUrl);
      const reposData = await reposRes.json();

      langsArray.push(
        ...reposData
          .filter(
            ({ fork, language }) =>
              language && !fork && allLang.find(({ lang }) => lang === language)
          )
          .map(({ language }) => language)
      );
    }
    const langNames = [...new Set(langsArray)];
    setUserData({
      loading: false,
      avatar: avatar_url,
      bio,
      login,
      name,
      lang: langNames.map(l => ({
        name: l,
        value: langsArray.filter(lang => lang === l).length,
        color: allLang.find(({ lang }) => lang === l).color
      }))
    });
  };

  return (
    <>
      <InputBlock>
        <h1>Language percentage in Github repository</h1>
        <TextField
          label="User Name"
          value={userName}
          onChange={inputHandler}
          onKeyPress={e => {
            if (e.key == 'Enter') {
              e.preventDefault();
              clickHandler();
            }
          }}
          variant="outlined"
          fullWidth
        />
        <Button
          variant="contained"
          color="primary"
          onClick={clickHandler}
          fullWidth
        >
          Search
        </Button>
      </InputBlock>
      {!!userData.login && (
        <DataBlock>
          <UserBlock>
            <img src={userData.avatar} alt={userData.login} />
            <p>{userData.name}</p>
            <p>{userData.login}</p>
            <p>{userData.bio}</p>
          </UserBlock>
          <ChartBlock>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  dataKey="value"
                  data={userData.lang}
                  label={({ name }) => name}
                >
                  {userData.lang.map(({ color }) => (
                    <Cell key={`${Math.random()}`} fill={color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </ChartBlock>
        </DataBlock>
      )}
      <ProgressDialog fullScreen open={userData.loading}>
        <CircularProgress />
      </ProgressDialog>
    </>
  );
};

const InputBlock = styled.div`
  padding: 16px;
  background-color: #0d1117;
  > h1 {
    font-size: 32px;
    margin-bottom: 16px;
  }
  > button {
    margin-top: 16px;
  }
`;

const DataBlock = styled.div`
  display: flex;
  height: calc(100% - 200px);
`;

const UserBlock = styled.div`
  display: flex;
  flex-direction: column;
  align-self: flex-start;
  padding: 16px;
  margin: 16px;
  max-width: 300px;
  background-color: #0d1117;
  > img {
    width: 260px;
    height: 260px;
    border-radius: 50%;
    margin-bottom: 16px;
  }
  > p:nth-of-type(1) {
    font-size: 26px;
    line-height: 1.25;
  }
  > p:nth-of-type(2) {
    font-size: 20px;
    font-weight: 300;
    line-height: 24px;
    margin-bottom: 16px;
  }
`;

const ChartBlock = styled.div`
  display: flex;
  flex: 1;
  padding: 16px;
  margin: 16px;
  background-color: #0d1117;
`;

const ProgressDialog = styled(Dialog)`
  z-index: 1000 !important;
  > div {
    background-color: rgba(255, 255, 255, 0.2);
    > div {
      position: absolute;
      top: calc(50% - 20px);
      left: calc(50% - 20px);
      background-color: transparent;
      box-shadow: none;
    }
  }
`;

export async function getStaticProps() {
  const res = await fetch(
    'https://raw.githubusercontent.com/github/linguist/master/lib/linguist/languages.yml'
  );
  const allLanguageYml = await res.text();
  const allLanguageObj = load(allLanguageYml);
  const allLang = Object.keys(allLanguageObj).map(key => ({
    lang: key,
    type: allLanguageObj[key].type,
    color: allLanguageObj[key].color || '#ccc'
  }));
  return {
    props: {
      allLang
    }
  };
}

export default App;
