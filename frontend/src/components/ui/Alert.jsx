// src/components/ui/Alert.jsx
import React from 'react';
import { XCircle, CheckCircle, Info } from 'lucide-react';

const variants = {
  error: {
    container: 'bg-red-50 border-red-200',
    icon: <XCircle className="h-5 w-5 text-red-400" />,
    text: 'text-red-700'
  },
  success: {
    container: 'bg-green-50 border-green-200',
    icon: <CheckCircle className="h-5 w-5 text-green-400" />,
    text: 'text-green-700'
  },
  info: {
    container: 'bg-blue-50 border-blue-200',
    icon: <Info className="h-5 w-5 text-blue-400" />,
    text: 'text-blue-700'
  }
};

export const Alert = ({
  message,
  variant = 'info',
  className = '',
  onClose
}) => {
  const styles = variants[variant];

  return (
    <div
      className={`
        border
        rounded-md
        p-4
        ${styles.container}
        ${className}
      `}
    >
      <div className="flex">
        <div className="flex-shrink-0">
          {styles.icon}
        </div>
        <div className="ml-3">
          <p className={`text-sm font-medium ${styles.text}`}>
            {message}
          </p>
        </div>
        {onClose && (
          <div className="ml-auto pl-3">
            <button
              onClick={onClose}
              className="inline-flex rounded-md p-1.5 focus:outline-none focus:ring-2 focus:ring-offset-2"
            >
              <XCircle className="h-5 w-5 text-gray-400" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
