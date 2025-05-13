import React, { useState, useEffect } from 'react';
import axios from 'axios';

function App() {
  // 状態管理の定義
  // API応答データを保持するstate
  const [data, setData] = useState('Loading...');
  // エラー情報を保持するstate
  const [error, setError] = useState(null);

  useEffect(() => {
    // APIエンドポイントの設定（環境変数から取得するか、ローカル開発用のデフォルト値を使用）
    const apiUrl = process.env.REACT_APP_API_URL || '/api/health';
    
    // APIへのリクエスト実行
    axios.get(apiUrl)
      .then(response => {
        // 成功時の処理：APIからのレスポンスデータをstateに設定
        setData(response.data.message);
      })
      .catch(err => {
        // エラー発生時の処理
        console.error('Error fetching data:', err);
        setError('Failed to fetch data from API');
      });
  }, []); // 空の依存配列で、コンポーネントマウント時に一度だけ実行

  return (
    <div className="App">
      <header className="App-header">
        <h1>CICD Sample Frontend</h1>
        {/* APIからのレスポンス表示（エラーがあればエラーメッセージを表示） */}
        <p>API Response: {error || data} ! new version with terraform!</p>
      </header>
    </div>
  );
}

export default App; 